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

func testHelm(t *testing.T, context spec.G, it spec.S) {
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

	context("detects a Helm chart", func() {
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
				Expect(docker.Container.Remove.Execute(container.ID)).To(Succeed())
			}
			Expect(docker.Volume.Remove.Execute(occam.CacheVolumeNames(name))).To(Succeed())
			if image.ID != "" {
				Expect(docker.Image.Remove.Execute(image.ID)).To(Succeed())
			}
			Expect(os.RemoveAll(source)).To(Succeed())
		})

		it("builds successfully and image contains packaged chart", func() {
			var err error
			source, err = occam.Source(filepath.Join("testdata", "helm"))
			Expect(err).NotTo(HaveOccurred())

			var logs fmt.Stringer
			image, logs, err = pack.Build.
				WithPullPolicy("always").
				WithBuilder(Builder).
				Execute(name, source)
			Expect(err).ToNot(HaveOccurred(), logs.String)

			Expect(logs).To(ContainLines(ContainSubstring("Octopilot Helm Buildpack")))
			Expect(logs).To(ContainLines(ContainSubstring("Packaging Helm chart")))

			// Run container with entrypoint to verify chart .tgz exists in the launch layer
			container, err = docker.Container.Run.
				WithEntrypoint("sh").
				WithCommand(`-c 'test -f /layers/octopilot/helm/helm-chart/chart/helm-smoke-0.1.0.tgz && test -f /layers/octopilot/helm/helm-chart/chart/chart.tgz && echo OK'`).
				Execute(image.ID)
			Expect(err).NotTo(HaveOccurred())

			// Wait for one-shot command to finish and capture logs
			Eventually(func() (string, error) {
				logs, err := docker.Container.Logs.Execute(container.ID)
				if err != nil {
					return "", err
				}
				return logs.String(), nil
			}).Should(ContainSubstring("OK"))
		})
	})
}
