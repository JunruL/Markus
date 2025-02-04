describe CoursePolicy do
  let(:context) { { role: role, real_user: role.end_user } }
  let(:role) { create :instructor }
  describe_rule :show? do
    succeed 'role is an instructor'
    failed 'role is a ta' do
      let(:role) { create :ta }
    end
    failed 'role is a student' do
      let(:role) { create :student }
    end
  end
  describe_rule :index? do
    succeed
  end
end
