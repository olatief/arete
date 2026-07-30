require "application_system_test_case"

class SignInTest < ApplicationSystemTestCase
  test "signing in leads to the dashboard and signing out returns to sign-in" do
    visit root_path

    fill_in "email_address", with: users(:one).email_address
    fill_in "password", with: "password"
    click_on I18n.t("sessions.new.submit")

    assert_text I18n.t("dashboard.show.title")
    assert_text I18n.t("dashboard.show.signed_in_as", email: users(:one).email_address)

    click_on I18n.t("dashboard.show.sign_out")
    assert_text I18n.t("sessions.new.title")
  end

  test "wrong password is rejected" do
    visit root_path

    fill_in "email_address", with: users(:one).email_address
    fill_in "password", with: "wrong-password"
    click_on I18n.t("sessions.new.submit")

    assert_text I18n.t("sessions.invalid_credentials")
  end
end
