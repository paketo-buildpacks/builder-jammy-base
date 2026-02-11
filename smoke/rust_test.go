package smoke_test

import (
	"fmt"
	"os"
	"path/filepath"
	"testing"

	"github.com/paketo-buildpacks/occam"
	"github.com/sclevine/spec"

	. "github.com/onsi/gomega"
	. "github.com/paketo-buildpacks/occam/matchers"
)

func testRust(t *testing.T, context spec.G, it spec.S) {
	var (
		Expect     = NewWithT(t).Expect
		Eventually = NewWithT(t).Eventually

		pack   occam.Pack
		docker occam.Docker
	)

	it.Before(func() {
		pack = occam.NewPack().WithVerbose().WithNoColor()
		docker = occam.NewDocker()
	})

	context("detects a Rust app", func() {
		var (
			image     occam.Image
			container occam.Container

			name   string
			source string
		)

		it.Before(func() {
			var err error
			name, err = occam.RandomName()
			Expect(err).NotTo(HaveOccurred())
		})

		it.After(func() {
			if container.ID != "" {
				_ = docker.Container.Remove.Execute(container.ID)
			}
			_ = docker.Volume.Remove.Execute(occam.CacheVolumeNames(name))
			if image.ID != "" {
				_ = docker.Image.Remove.Execute(image.ID)
			}
			Expect(os.RemoveAll(source)).To(Succeed())
		})

		it("builds successfully", func() {
			var err error
			source, err = occam.Source(filepath.Join("testdata", "rust"))
			Expect(err).NotTo(HaveOccurred())

			var logs fmt.Stringer
			image, logs, err = pack.Build.
				WithPullPolicy("always").
				WithBuilder(Builder).
				Execute(name, source)
			Expect(err).ToNot(HaveOccurred(), logs.String)

			container, err = docker.Container.Run.
				WithCommand("/workspace/bin/rust-smoke").
				WithEnv(map[string]string{"PORT": "8080"}).
				WithPublish("8080").
				Execute(image.ID)
			Expect(err).NotTo(HaveOccurred())

			Eventually(container).Should(BeAvailable())

			Expect(logs).To(ContainLines(ContainSubstring("octopilot/rust")))
		})
	})

	context("Rust workspace (monolith)", func() {
		var (
			image     occam.Image
			container occam.Container

			name   string
			source string
		)

		it.Before(func() {
			var err error
			name, err = occam.RandomName()
			Expect(err).NotTo(HaveOccurred())
		})

		it.After(func() {
			if container.ID != "" {
				_ = docker.Container.Remove.Execute(container.ID)
			}
			_ = docker.Volume.Remove.Execute(occam.CacheVolumeNames(name))
			if image.ID != "" {
				_ = docker.Image.Remove.Execute(image.ID)
			}
			Expect(os.RemoveAll(source)).To(Succeed())
		})

		it("builds all binaries and backend process works", func() {
			var err error
			source, err = occam.Source(filepath.Join("testdata", "rust-workspace"))
			Expect(err).NotTo(HaveOccurred())

			var logs fmt.Stringer
			image, logs, err = pack.Build.
				WithPullPolicy("always").
				WithBuilder(Builder).
				WithEnv(map[string]string{"BP_RUST_FEATURES": "dioxus-app-backend/server"}).
				Execute(name, source)
			Expect(err).ToNot(HaveOccurred(), logs.String)

			container, err = docker.Container.Run.
				WithCommand("/workspace/bin/dioxus-app-backend").
				WithEnv(map[string]string{"PORT": "8080"}).
				WithPublish("8080").
				Execute(image.ID)
			Expect(err).NotTo(HaveOccurred())

			Eventually(container).Should(BeAvailable())

			Expect(logs).To(ContainLines(ContainSubstring("octopilot/rust")))
			Expect(logs).To(ContainLines(ContainSubstring("binary(ies)")))
		})
	})
}
