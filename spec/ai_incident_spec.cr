require "./helper"

module PlaceOS::Model
  describe AiIncident do
    it "provides report lifecycle defaults and validates required fields" do
      incident = AiIncident.new

      incident.status.should eq "open"
      incident.severity.should eq "info"
      incident.source.should eq "webhook"
      incident.classification.should eq "unknown"
      incident.confidence.should eq 0.0
      incident.summary.should eq ""
      incident.report_schema_version.should eq "incident-report.v1"
      incident.duplicate_count.should eq 0
      incident.valid?.should be_false
      incident.errors.map(&.field).should contain(:correlation_key)
    end

    it "persists incident state and report artefacts" do
      incident = AiIncident.new
      incident.status = "diagnosed"
      incident.severity = "warning"
      incident.source = "grafana"
      incident.classification = "module_runtime_error"
      incident.confidence = 0.87
      incident.summary = "The module reported a runtime error"
      incident.correlation_key = "module:mod-1234"
      incident.tenant_id = "tenant-1234"
      incident.system_id = "sys-1234"
      incident.module_id = "mod-1234"
      incident.module_name = "Display"
      incident.module_index = 1
      incident.duplicate_count = 2
      incident.last_seen_at = Time.utc
      incident.save!

      event = AiIncidentEvent.new
      event.incident_id = incident.id.as(String)
      event.source = "grafana"
      event.severity = "warning"
      event.correlation_key = incident.correlation_key
      event.payload = JSON.parse(%({"message":"runtime error"}))
      event.received_at = Time.utc
      event.save!

      report = AiIncidentReport.new
      report.incident_id = incident.id.as(String)
      report.status = "diagnosed"
      report.classification = incident.classification
      report.confidence = incident.confidence
      report.report_json = JSON.parse(%({"summary":"The module reported a runtime error"}))
      report.evidence_json = JSON.parse(%([{"source":"grafana"}]))
      report.investigation_json = JSON.parse(%([{"tool":"module_state"}]))
      report.decision_json = JSON.parse(%({"outcome":"report_only"}))
      report.markdown = "# Incident report"
      report.save!

      run = AiAgentRun.new
      run.incident_id = incident.id.as(String)
      run.correlation_key = incident.correlation_key
      run.classification = incident.classification
      run.confidence = incident.confidence
      run.plan_json = JSON.parse(%({"steps":["module_state"]}))
      run.investigation_json = report.investigation_json
      run.decision_json = report.decision_json
      run.remediation_proposal_json = JSON.parse(%({"execution_mode":"proposal_only"}))
      run.save!

      persisted = AiIncident.find!(incident.id.as(String))
      persisted.status.should eq "diagnosed"
      persisted.module_id.should eq "mod-1234"
      persisted.duplicate_count.should eq 2
      persisted.events.map(&.id).should contain(event.id)
      persisted.reports.map(&.id).should contain(report.id)
      persisted.agent_runs.map(&.id).should contain(run.id)

      AiIncidentReport.find!(report.id.as(Int64)).report_json.should eq report.report_json
      AiAgentRun.find!(run.id.as(Int64)).remediation_proposal_json.should eq run.remediation_proposal_json
    ensure
      incident.try &.delete
    end

    it "persists incident workflow audit records and associations" do
      incident = AiIncident.new
      incident.correlation_key = "module:mod-audit"
      incident.save!
      incident_id = incident.id.as(String)
      now = Time.utc

      approval = AiApprovalRequest.new
      approval.id = "approval-1"
      approval.incident_id = incident_id
      approval.requested_by = "operator@example.com"
      approval.request_note = "Review this proposal"
      approval.proposal_json = JSON.parse(%({"action":"restart_module"}))
      approval.save!

      delivery = AiReportDelivery.new
      delivery.incident_id = incident_id
      delivery.status = "delivered"
      delivery.destination = "https://example.test/incidents"
      delivery.attempted_at = now
      delivery.response_status = 202
      delivery.save!

      verification = AiVerificationRun.new
      verification.id = "verification-1"
      verification.incident_id = incident_id
      verification.procedure_id = "module-runtime-recovery"
      verification.procedure_version = 1
      verification.procedure_hash = "verification-hash"
      verification.attempt = 1
      verification.status = "passed"
      verification.checks_json = JSON.parse(%([{"check":"runtime_error_cleared"}]))
      verification.evidence_json = JSON.parse(%([{"value":false}]))
      verification.started_at = now
      verification.completed_at = now
      verification.save!

      escalation = AiEscalationRecord.new
      escalation.id = "escalation-1"
      escalation.incident_id = incident_id
      escalation.procedure_id = "operations-escalation"
      escalation.procedure_version = 1
      escalation.procedure_hash = "escalation-hash"
      escalation.owner_queue = "building-operations"
      escalation.response_sla_minutes = 30
      escalation.reason = "Operator review is required"
      escalation.required_artefacts_json = JSON.parse(%(["incident_report"]))
      escalation.delivery_status = "delivered"
      escalation.delivery_destination = "support@example.com"
      escalation.response_due_at = now + 30.minutes
      escalation.escalated_at = now
      escalation.save!

      feedback = AiIncidentFeedback.new
      feedback.id = "feedback-1"
      feedback.incident_id = incident_id
      feedback.rating = "helpful"
      feedback.submitted_by = "operator@example.com"
      feedback.comment = "Correct diagnosis"
      feedback.submitted_at = now
      feedback.save!

      persisted = AiIncident.find!(incident_id)
      persisted.approval_requests.map(&.id).should contain(approval.id)
      persisted.report_deliveries.map(&.id).should contain(delivery.id)
      persisted.verification_runs.map(&.id).should contain(verification.id)
      persisted.escalation_records.map(&.id).should contain(escalation.id)
      persisted.feedback.map(&.id).should contain(feedback.id)

      incident.delete

      AiApprovalRequest.find?(approval.id.as(String)).should be_nil
      AiReportDelivery.find?(delivery.id.as(Int64)).should be_nil
      AiVerificationRun.find?(verification.id.as(String)).should be_nil
      AiEscalationRecord.find?(escalation.id.as(String)).should be_nil
      AiIncidentFeedback.find?(feedback.id.as(String)).should be_nil
    ensure
      incident.try &.delete
    end
  end

  describe "AI support operational records" do
    it "persists maintenance, correlation, and trend records" do
      now = Time.utc

      maintenance = AiMaintenanceRun.new
      maintenance.id = "maintenance-1"
      maintenance.procedure_id = "daily-runtime-review"
      maintenance.procedure_version = 1
      maintenance.procedure_hash = "maintenance-hash"
      maintenance.schedule_bucket = 20260730_i64
      maintenance.status = "completed"
      maintenance.target_count = 1
      maintenance.incident_ids_json = JSON.parse(%(["incident-1"]))
      maintenance.classification_counts_json = JSON.parse(%({"module_runtime_error":1}))
      maintenance.started_at = now
      maintenance.completed_at = now
      maintenance.save!

      finding = AiCorrelationFinding.new
      finding.id = "finding-1"
      finding.deduplication_key = "runtime-errors:sys-1234"
      finding.kind = "recurring_failure"
      finding.policy_id = "recurring-runtime-errors"
      finding.policy_version = 1
      finding.policy_hash = "correlation-hash"
      finding.scope_key = "system:sys-1234"
      finding.system_id = "sys-1234"
      finding.classification = "module_runtime_error"
      finding.incident_ids_json = JSON.parse(%(["incident-1"]))
      finding.observation_count = 3
      finding.transition_count = 2
      finding.window_start = now - 1.hour
      finding.window_end = now
      finding.summary = "Three related runtime errors were observed"
      finding.detected_at = now
      finding.save!

      trend = AiTrendReport.new
      trend.id = "trend-1"
      trend.policy_id = "weekly-support-trends"
      trend.policy_version = 1
      trend.policy_hash = "trend-hash"
      trend.window_start = now - 7.days
      trend.window_end = now
      trend.summary_json = JSON.parse(%({"incident_count":3}))
      trend.markdown = "# Weekly support trends"
      trend.generated_at = now
      trend.save!

      AiMaintenanceRun.find!("maintenance-1").incident_ids_json.should eq maintenance.incident_ids_json
      AiCorrelationFinding.find!("finding-1").deduplication_key.should eq finding.deduplication_key
      AiTrendReport.find!("trend-1").summary_json.should eq trend.summary_json
    ensure
      maintenance.try &.delete
      finding.try &.delete
      trend.try &.delete
    end
  end
end
