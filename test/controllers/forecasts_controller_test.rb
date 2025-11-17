require "test_helper"

class ForecastsControllerTest < ActionDispatch::IntegrationTest
  test "should get new" do
    get forecasts_new_url
    assert_response :success
  end
end
