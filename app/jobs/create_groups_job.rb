# create groups job
class CreateGroupsJob < ApplicationJob

  def self.on_complete_js(_status)
    '() => {window.groupsManager && window.groupsManager.fetchData()}'
  end

  def self.show_status(status)
    I18n.t('poll_job.create_groups_job', progress: status[:progress], total: status[:total])
  end

  def perform(assignment, data)
    progress.total = data.length
    Repository.get_class.update_permissions_after(only_on_request: true) do
      ApplicationRecord.transaction do
        data.each do |group_name, *members|
          students = Student.where(user_name: members)
          if students.length != members.length
            # A member in the members list is not a User in the database
            all_users = Set.new students.pluck(:user_name)
            bad_names = (Set.new(members) - all_users).to_a.join(', ')
            msg = I18n.t('csv.member_does_not_exist', group_name: group_name, student_user_name: bad_names)
            status.update(error_message: msg)
            Rails.logger.error msg
            raise ActiveRecord::Rollback
          end
          inviter, *others = students.to_a
          errors = []
          if assignment.is_timed
            grouping = inviter.create_autogenerated_name_group(assignment.id)
          else
            group = Group.find_or_create_by(group_name: group_name)
            grouping = Grouping.find_or_create_by(group: group, assignment: assignment)
            errors += grouping.invite(inviter.user_name, StudentMembership::STATUSES[:inviter], true)
          end
          errors += grouping.invite(others.map(&:user_name), StudentMembership::STATUSES[:accepted])
          unless errors.empty?
            msg = errors.join("\n")
            status.update(error_message: msg)
            Rails.logger.error msg
            raise ActiveRecord::Rollback
          end
          progress.increment
        end
      end
    end
    m_logger = MarkusLogger.instance
    m_logger.log('Creating all individual groups completed',
                 MarkusLogger::INFO)
  end
end
