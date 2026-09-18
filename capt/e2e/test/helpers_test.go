package e2e

import (
	"strings"
	"testing"

	tinkv1 "github.com/tinkerbell/tinkerbell/api/v1alpha1/tinkerbell"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

func TestTerminalWorkflowStates(t *testing.T) {
	for _, tc := range []struct {
		state tinkv1.WorkflowState
		want  bool
	}{
		{tinkv1.WorkflowStateFailed, true},
		{tinkv1.WorkflowStateTimeout, true},
		{tinkv1.WorkflowStateRunning, false},
		{tinkv1.WorkflowStatePending, false},
		{tinkv1.WorkflowStateSuccess, false},
	} {
		if got := isTerminalWorkflowState(tc.state); got != tc.want {
			t.Errorf("isTerminalWorkflowState(%s) = %v, want %v", tc.state, got, tc.want)
		}
	}
}

// A terminal failure has to explain itself, or reading it means going back to
// the cluster that the run has already torn down.
func TestWorkflowFailureDetail(t *testing.T) {
	wf := tinkv1.Workflow{
		Status: tinkv1.WorkflowStatus{
			State: tinkv1.WorkflowStateFailed,
			CurrentState: &tinkv1.CurrentState{
				TaskName:   "playground-template",
				ActionName: "kexec image",
				State:      tinkv1.WorkflowStateSuccess,
			},
			Conditions: []tinkv1.WorkflowCondition{
				{Type: "TemplateRenderedSuccess", Status: metav1.ConditionTrue, Message: "fine"},
				{Type: "BootJobSetupFailed", Status: metav1.ConditionTrue, Message: `job "iso-eject" already exists`},
				{Type: "SomeOtherFailed", Status: metav1.ConditionFalse, Message: "not active"},
			},
		},
	}

	got := workflowFailureDetail(wf)

	for _, want := range []string{"playground-template", "kexec image", "BootJobSetupFailed", "iso-eject"} {
		if !strings.Contains(got, want) {
			t.Errorf("detail missing %q:\n%s", want, got)
		}
	}
	// Conditions that are not active must not be reported as causes.
	if strings.Contains(got, "SomeOtherFailed") {
		t.Errorf("detail reported an inactive condition:\n%s", got)
	}
	if strings.Contains(got, "TemplateRenderedSuccess") {
		t.Errorf("detail reported a non-failure condition:\n%s", got)
	}
}
