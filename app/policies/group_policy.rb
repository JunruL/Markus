# Group policy class
class GroupPolicy < ApplicationPolicy
  default_rule :manage?
  alias_rule :create?, :destroy?, :delete_rejected?, :disinvite_member?, :invite_member?, :accept_invitation?,
             :decline_invitation?, :download_starter_file?, to: :student_manage?
  def student_manage?
    role.student?
  end

  def manage?
    check?(:manage_assessments?, role)
  end
end
