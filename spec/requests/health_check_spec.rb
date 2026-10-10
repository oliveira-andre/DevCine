require 'rails_helper'

# GET /health_check (services_health_check), read by the intranet's Apps page.
# No sign-in anywhere here: the intranet sends no credentials, so the endpoint
# must answer without one.
RSpec.describe "GET /health_check", type: :request do
  def stub_checks(results)
    allow_any_instance_of(HealthCheckService).to receive(:call).and_return(results)
  end

  it "answers 200 with every check when all pass" do
    stub_checks(app: true, database: true)
    get "/health_check"

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("application/json")
    expect(response.parsed_body).to eq("app" => true, "database" => true)
  end

  it "answers 503 when a check fails, still naming every check" do
    stub_checks(app: true, database: false)
    get "/health_check"

    expect(response).to have_http_status(:service_unavailable)
    expect(response.parsed_body).to eq("app" => true, "database" => false)
  end

  it "answers JSON even when the service raises" do
    allow_any_instance_of(HealthCheckService).to receive(:call).and_raise("boom")
    get "/health_check", headers: { "Accept" => "text/html" }

    expect(response).to have_http_status(:service_unavailable)
    expect(response.media_type).to eq("application/json")
    expect(response.parsed_body).to eq("app" => false)
  end
end
