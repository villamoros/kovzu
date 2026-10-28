class SessionsController < ApplicationController
  def sign_in
    redirect_to dashboard_path if signed_in?
  end

  def sign_up
    redirect_to dashboard_path if signed_in?
  end
end
