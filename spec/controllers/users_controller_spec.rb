describe UsersController do
  let(:role) { create(:instructor) }
  let(:user) { role.end_user }

  shared_examples 'settings' do
    describe '#update_settings' do
      it 'updates locale' do
        I18n.locale = :en
        locale = 'es'
        patch_as user, 'update_settings', params: { 'user': { 'locale': locale } }

        expect(user.reload.locale).to eq locale
        expect(I18n.locale).to eq locale.to_sym
      end

      it 'updates display_name' do
        display_name = 'First Last'
        patch_as user,
                 'update_settings',
                 params: { 'user': { 'display_name': display_name } }
        expect(user.reload.display_name).to eq display_name
      end

      it 'updates time zone' do
        time_zone = 'Pacific Time (US & Canada)'
        patch_as user,
                 'update_settings',
                 params: { 'user': { 'time_zone': time_zone } }
        expect(user.reload.time_zone).to eq time_zone
      end

      it 'updates student display_name' do
        display_name = 'First Last'
        patch_as user,
                 'update_settings',
                 params: { 'user': { 'display_name': display_name } }
        expect(user.reload.display_name).to eq display_name
      end
    end

    describe '#settings' do
      before { get_as user, :settings }
      it 'should respond with success' do
        is_expected.to respond_with(:success)
      end
      it 'should render settings' do
        expect(response).to render_template(:settings)
      end
    end
  end

  describe 'User is an instructor in at least one course' do
    describe '#reset_api_key' do
      it 'responds with a success' do
        post_as user, :reset_api_key
        expect(response).to have_http_status(:success)
      end
      it 'changes their api key' do
        old_key = user.api_key
        post_as user, :reset_api_key
        user.reload
        expect(user.api_key).not_to eq(old_key)
      end
    end

    include_examples 'settings'
  end

  describe 'User is not an instructor in at least one course' do
    let(:role) { create :ta }
    describe '#reset_api_key' do
      it 'cannot reset their api key' do
        post_as user, :reset_api_key
        expect(response).to have_http_status(:forbidden)
      end
    end
    include_examples 'settings'
  end
end
