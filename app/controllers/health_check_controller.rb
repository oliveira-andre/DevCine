# GET /health_check: always JSON, 200 when every check passes, 503 otherwise (services_health_check).
class HealthCheckController < ActionController::API
  def show
    results = HealthCheckService.new.call
    render json: results, status: results.values.all? ? :ok : :service_unavailable
  rescue StandardError, ScriptError => error
    Rails.logger.error("[services_health_check] #{error.class}: #{error.message}")
    render json: { app: false }, status: :service_unavailable
  end
end
