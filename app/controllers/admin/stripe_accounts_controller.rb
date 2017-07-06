module Admin
  class StripeAccountsController < BaseController
    include Admin::StripeHelper
    protect_from_forgery except: :destroy_from_webhook

    def destroy
      if deauthorize_stripe(params[:id])
        respond_to do |format|
          format.html { redirect_to main_app.edit_admin_enterprise_path(params[:enterprise_id]), notice: "Stripe account disconnected."}
          format.json { render json: stripe_account }
        end
      else
        respond_to do |format|
          format.html { redirect_to main_app.edit_admin_enterprise_path(params[:enterprise_id]), notice: "Failed to disconnect Stripe."}
          format.json { render json: stripe_account }
        end
      end
    end

    def destroy_from_webhook
      # Fetch the event again direct from stripe for extra security
      event = fetch_event_from_stripe(request)
      if event.type == "account.application.deauthorized"
        StripeAccount.where(stripe_user_id: event.user_id).map{ |account| account.destroy }
        render text: "Account #{event.user_id} deauthorized", status: 200
      else
        render json: nil, status: 501
      end
    end

    def status
      authorize! :stripe_account, Enterprise.find_by_id(params[:enterprise_id])
      return render json: { status: :stripe_disabled } unless Spree::Config.stripe_connect_enabled
      stripe_account = StripeAccount.find_by_enterprise_id(params[:enterprise_id])
      return render json: { status: :account_missing } unless stripe_account

      begin
        status = Stripe::Account.retrieve(stripe_account.stripe_user_id)
        attrs = [:id, :business_name, :charges_enabled]
        render json: status.to_hash.slice(*attrs).merge( status: :connected)
      rescue Stripe::APIError => e
        render json: { status: :access_revoked }
      end
    end
  end
end