# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.
class ApplicationController < ActionController::Base
  include ApplicationHelper, SessionHandler
  include UploadHelper
  include DownloadHelper

  authorize :role, through: :current_role
  authorize :real_user, through: :real_user
  authorize :real_role, through: :real_role
  verify_authorized
  rescue_from ActionPolicy::Unauthorized, with: :user_not_authorized

  # responder set up
  self.responder = ApplicationResponder
  respond_to :html

  protect_from_forgery with: :exception

  layout 'content'

  helper :all # include all helpers in the views, all the time

  # set user time zone based on their settings
  around_action :use_time_zone, if: :current_user
  # activate i18n for renaming constants in views
  before_action :set_locale, :set_markus_version, :get_file_encodings
  # check for active session on every page
  before_action :authenticate, :check_course_switch, :check_record,
                except: [:login, :page_not_found, :check_timeout, :login_remote_auth]
  # check for AJAX requests
  after_action :flash_to_headers

  # Define default URL options to include the locale if the user is not logged in
  def default_url_options(options={})
    if current_user
      {}
    else
      { locale: I18n.locale }
    end
  end

  def page_not_found
    render 'shared/http_status',
           formats: [:html],
           locals: { code: '404', message: HttpStatusHelper::ERROR_CODE['message']['404'] },
           status: 404,
           layout: false
  end

  protected

  def use_time_zone(&block)
    Time.use_zone(current_user.time_zone, &block)
  end

  # Set version for MarkUs to be available in
  # any view
  def set_markus_version
    version_file=File.expand_path(File.join(::Rails.root.to_s, 'app', 'MARKUS_VERSION'))
    unless File.exist?(version_file)
      @markus_version = 'unknown'
      return
    end
    content = File.new(version_file).read
    version_info = Hash.new
    content.split(',').each do |token|
      k,v = token.split('=')
      version_info[k.downcase] = v
    end
    @markus_version = "#{version_info['version']}.#{version_info['patch_level']}"
  end

  # Set locale according to URL parameter. If unknown parameter is
  # requested, fall back to default locale.
  def set_locale
    if params[:locale].nil?
      if current_user && I18n.available_locales.include?(current_user.locale.to_sym)
        I18n.locale = current_user.locale
      else
        I18n.locale = I18n.default_locale
      end
    elsif I18n.available_locales.include? params[:locale].to_sym
      I18n.locale = params[:locale]
    else
      flash_now(:notice, I18n.t('locale_not_available', locale: params[:locale]))
    end
  end

  def get_file_encodings
    @encodings = [%w(Unicode UTF-8), %w(ISO-8859-1 ISO-8859-1)]
  end

  # add flash message to AJAX response headers
  def flash_to_headers
    return unless request.xhr?
    [:error, :success, :warning, :notice].each do |key|
      unless flash[key].nil?
        if flash[key].is_a?(Array)
          str = flash[key].join(';')
        else
          str = flash[key]
        end
        response.headers["X-Message-#{key}"] = str
      end
    end
    flash.discard
  end

  # dynamically hide a flash message (for AJAX requests only)
  def hide_flash(key)
    return unless request.xhr?

    discard_header = response.headers['X-Message-Discard']
    if discard_header.nil?
      response.headers['X-Message-Discard'] = key.to_s
    else
      response.headers['X-Message-Discard'] = "#{key};#{discard_header}"
    end
  end

  def user_not_authorized
    render 'shared/http_status',
           formats: [:html], locals: { code: '403', message: HttpStatusHelper::ERROR_CODE['message']['403'] },
           status: 403, layout: false
  end

  # Render 403 if the current user is switching roles and they try to view a route for a different course
  def check_course_switch
    user_not_authorized if session[:role_switch_course_id] && current_course&.id != session[:role_switch_course_id]
  end

  def implicit_authorization_target
    controller_name.classify.constantize.find_or_initialize_by(identification_params)
  end

  def identification_params
    params.permit(:id)
  end
end
