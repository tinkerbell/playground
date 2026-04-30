package e2e

import (
	"context"
	"time"

	. "github.com/onsi/ginkgo/v2"
)

// ctx is a package-level context used across all test specs.
var ctx = context.TODO()

var _ = Describe("Workload cluster provisioning", Label("provisioning"), Ordered, func() {
	var (
		workflowTimeout  = 25 * time.Minute
		workflowInterval = 10 * time.Second
		nodeTimeout      = 10 * time.Minute
		nodeInterval     = 10 * time.Second
		expectedNodes    = 2 // 1 control plane + 1 worker
	)

	// Override from E2E config if loaded.
	BeforeAll(func() {
		if t, i := e2eConfig.GetInterval("default/wait-workflow"); t > 0 {
			workflowTimeout = t
			workflowInterval = i
		}
		if t, i := e2eConfig.GetInterval("default/wait-nodes"); t > 0 {
			nodeTimeout = t
			nodeInterval = i
		}
	})

	AfterAll(func() {
		By("Dumping workflows and hardware for debugging")
		ListWorkflows(ctx, tinkClient, namespace)
		ListHardware(ctx, tinkClient, namespace)
	})

	It("completes all workflows successfully", func() {
		WaitForWorkflowsSuccess(ctx, tinkClient, namespace, expectedNodes, workflowTimeout, workflowInterval)
	})

	It("has a reachable workload API server", func() {
		WaitForAPIServerReady(workloadKubeconfig, nodeTimeout, 10*time.Second)
	})

	It("deploys CNI to the workload cluster", func() {
		DeployCNI(workloadKubeconfig)
	})

	It("has all nodes Ready after CNI deployment", func() {
		WaitForAllNodesReady(ctx, workloadClient, expectedNodes, nodeTimeout, nodeInterval)
	})
})
