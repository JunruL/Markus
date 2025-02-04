describe ResultsController do
  # TODO: add 'role is from a different course' shared tests to each route test below
  let(:course) { assignment.course }
  let(:assignment) { create :assignment }
  let(:student) { create :student, grace_credits: 2 }
  let(:instructor) { create :instructor }
  let(:ta) { create :ta }
  let(:grouping) { create :grouping_with_inviter, assignment: assignment, inviter: student }
  let(:submission) { create :version_used_submission, grouping: grouping }
  let(:incomplete_result) { submission.current_result }
  let(:complete_result) { create :complete_result, submission: submission }
  let(:submission_file) { create :submission_file, submission: submission }
  let(:rubric_criterion) { create(:rubric_criterion, assignment: assignment) }
  let(:rubric_mark) { create :rubric_mark, result: incomplete_result, criterion: rubric_criterion }
  let(:flexible_criterion) { create(:flexible_criterion, assignment: assignment) }
  let(:flexible_mark) { create :flexible_mark, result: incomplete_result, criterion: flexible_criterion }
  let(:from_codeviewer) { nil }

  SAMPLE_FILE_CONTENT = 'sample file content'.freeze
  SAMPLE_ERROR_MESSAGE = 'sample error message'.freeze
  SAMPLE_COMMENT = 'sample comment'.freeze
  SAMPLE_FILE_NAME = 'file.java'.freeze

  after(:each) do
    destroy_repos
  end

  def self.test_assigns_not_nil(key)
    it "should assign #{key}" do
      expect(assigns key).not_to be_nil
    end
  end

  def self.test_no_flash
    it 'should not display any flash messages' do
      expect(flash).to be_empty
    end
  end

  def self.test_unauthorized(route_name)
    it "should not be authorized to access #{route_name}" do
      method(ROUTES[route_name]).call(route_name, params: { course_id: course.id, id: incomplete_result.id })
      expect(response).to have_http_status(:forbidden)
    end
  end

  shared_examples 'download files' do
    context 'and without any file errors' do
      before :each do
        allow_any_instance_of(SubmissionFile).to receive(:retrieve_file).and_return SAMPLE_FILE_CONTENT
        get :download, params: { course_id: course.id,
                                 select_file_id: submission_file.id,
                                 from_codeviewer: from_codeviewer,
                                 id: incomplete_result.id }
      end
      it { expect(response).to have_http_status(:success) }
      test_no_flash
      it 'should have the correct content type' do
        expect(response.header['Content-Type']).to eq 'text/plain'
      end
      it 'should show the file content in the response body' do
        expect(response.body).to eq SAMPLE_FILE_CONTENT
      end
    end
    context 'and with a file error' do
      before :each do
        allow_any_instance_of(SubmissionFile).to receive(:retrieve_file).and_raise SAMPLE_ERROR_MESSAGE
        get :download, params: { course_id: course.id,
                                 select_file_id: submission_file.id,
                                 from_codeviewer: from_codeviewer,
                                 id: incomplete_result.id }
      end
      it { expect(response).to have_http_status(:redirect) }
      it 'should display a flash error' do
        expect(extract_text(flash[:error][0])).to eq SAMPLE_ERROR_MESSAGE
      end
    end
    context 'and with a supported image file shown in browser' do
      before :each do
        allow_any_instance_of(SubmissionFile).to receive(:is_supported_image?).and_return true
        allow_any_instance_of(SubmissionFile).to receive(:retrieve_file).and_return SAMPLE_FILE_CONTENT
        get :download, params: { course_id: course.id,
                                 select_file_id: submission_file.id,
                                 id: incomplete_result.id,
                                 from_codeviewer: from_codeviewer,
                                 show_in_browser: true }
      end
      it { expect(response).to have_http_status(:success) }
      test_no_flash
      it 'should have the correct content type' do
        expect(response.header['Content-Type']).to eq 'image'
      end
      it 'should show the file content in the response body' do
        expect(response.body).to eq SAMPLE_FILE_CONTENT
      end
    end
    context 'show in browser is true' do
      let(:submission_file) { create :submission_file, filename: filename, submission: submission }
      subject do
        get :download, params: { course_id: course.id,
                                 select_file_id: submission_file.id,
                                 id: incomplete_result.id,
                                 from_codeviewer: from_codeviewer,
                                 show_in_browser: true }
      end
      context 'file is a jupyter-notebook file' do
        let(:filename) { 'example.ipynb' }
        it 'should redirect to "notebook_content"' do
          expect(subject).to(
            redirect_to(notebook_content_course_assignment_submissions_path(course,
                                                                            assignment,
                                                                            select_file_id: submission_file.id))
          )
        end
      end
      context 'file is a rmarkdown file' do
        let(:filename) { 'example.Rmd' }
        it 'should redirect to "notebook_content"' do
          expect(subject).to(
            redirect_to(notebook_content_course_assignment_submissions_path(course,
                                                                            assignment,
                                                                            select_file_id: submission_file.id))
          )
        end
      end
    end
  end

  shared_examples 'shared ta and instructor tests' do
    include_examples 'download files'
    context 'accessing next_grouping' do
      it 'should receive 200 when current grouping has a submission' do
        allow_any_instance_of(Grouping).to receive(:has_submission).and_return true
        get :next_grouping, params: { course_id: course.id, grouping_id: grouping.id, id: incomplete_result.id }
        expect(response).to have_http_status(:ok)
      end
      it 'should receive 200 when current grouping does not have a submission' do
        allow_any_instance_of(Grouping).to receive(:has_submission).and_return false
        get :next_grouping, params: { course_id: course.id, grouping_id: grouping.id, id: incomplete_result.id }
        expect(response).to have_http_status(:ok)
      end
      it 'should receive a JSON object of the next grouping when next grouping has a submission' do
        a2 = create(:assignment_with_criteria_and_results)
        get :next_grouping, params: { course_id: course.id,
                                      grouping_id: a2.groupings.first.id,
                                      id: a2.submissions.first.current_result.id }
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('next_result', 'next_grouping')
      end
    end
    context 'accessing toggle_marking_state' do
      context 'with a complete result' do
        before :each do
          post :toggle_marking_state, params: { course_id: course.id, id: complete_result.id }, xhr: true
        end
        it { expect(response).to have_http_status(:success) }
        # TODO: test that the grade distribution is refreshed
      end
    end
    context 'accessing download_zip' do
      before :each do
        grouping.group.access_repo do |repo|
          txn = repo.get_transaction('test')
          path = File.join(assignment.repository_folder, SAMPLE_FILE_NAME)
          txn.add(path, SAMPLE_FILE_CONTENT, '')
          repo.commit(txn)
          @submission = Submission.generate_new_submission(grouping, repo.get_latest_revision)
        end
        file = SubmissionFile.find_by_submission_id(@submission.id)
        @annotation = TextAnnotation.create  line_start: 1,
                                             line_end: 2,
                                             column_start: 1,
                                             column_end: 2,
                                             submission_file_id: file.id,
                                             is_remark: false,
                                             annotation_number: @submission.annotations.count + 1,
                                             annotation_text: create(:annotation_text, creator: instructor),
                                             result: complete_result,
                                             creator: instructor
        file_name_snippet = grouping.group.access_repo do |repo|
          "#{assignment.short_identifier}_#{grouping.group.group_name}_r#{repo.get_latest_revision.revision_identifier}"
        end
        @file_path_ann = File.join 'tmp', "#{file_name_snippet}_ann.zip"
        @file_path = File.join 'tmp', "#{file_name_snippet}.zip"
        submission_file_dir = "#{assignment.repository_folder}-#{grouping.group.repo_name}"
        @submission_file_path = File.join(submission_file_dir, SAMPLE_FILE_NAME)
      end
      after :each do
        FileUtils.rm_f @file_path_ann
        FileUtils.rm_f @file_path
      end
      context 'and including annotations' do
        before :each do
          get :download_zip, params: { course_id: course.id,
                                       id: @submission.results.first.id,
                                       grouping_id: grouping.id,
                                       include_annotations: 'true' }
        end
        after :each do
          FileUtils.rm_f @file_path_ann
        end
        it { expect(response).to have_http_status(:success) }
        it 'should have make the correct content type' do
          expect(response.header['Content-Type']).to eq 'application/zip'
        end
        it 'should create a zip file' do
          File.exist? @file_path_ann
        end
        it 'should create a zip file containing the submission file' do
          Zip::File.open(@file_path_ann) do |zip_file|
            expect(zip_file.find_entry(@submission_file_path)).not_to be_nil
          end
        end
        it 'should include the annotations in the file output' do
          Zip::File.open(@file_path_ann) do |zip_file|
            expect(zip_file.read(@submission_file_path)).to include(@annotation.annotation_text.content)
          end
        end
      end
      context 'and not including annotations' do
        before :each do
          get :download_zip, params: { course_id: course.id,
                                       id: @submission.results.first.id,
                                       grouping_id: grouping.id,
                                       include_annotations: 'false' }
        end
        after :each do
          FileUtils.rm_f @file_path
        end
        it { expect(response).to have_http_status(:success) }
        it 'should have make the correct content type' do
          expect(response.header['Content-Type']).to eq 'application/zip'
        end
        it 'should create a zip file' do
          File.exist? @file_path
        end
        it 'should create a zip file containing the submission file' do
          Zip::File.open(@file_path) do |zip_file|
            expect(zip_file.find_entry(@submission_file_path)).not_to be_nil
          end
        end
        it 'should not include the annotations in the file output' do
          Zip::File.open(@file_path) do |zip_file|
            expect(zip_file.read(@submission_file_path)).not_to include(@annotation.annotation_text.content)
          end
        end
      end
    end
    context 'accessing update_mark' do
      it 'should report an updated mark' do
        patch :update_mark, params: { course_id: course.id,
                                      id: incomplete_result.id,
                                      criterion_id: rubric_mark.criterion_id,
                                      mark: 1 }, xhr: true
        expect(JSON.parse(response.body)['num_marked']).to eq 0
        expect(rubric_mark.reload.override).to be true
      end
      context 'setting override when annotations linked to criteria exist' do
        let(:assignment) { create(:assignment_with_deductive_annotations) }
        let(:result) { assignment.groupings.first.current_result }
        let(:submission) { result.submission }
        let(:mark) { assignment.groupings.first.current_result.marks.first }
        it 'sets override to true for mark if input value is not null' do
          patch :update_mark, params: { course_id: course.id,
                                        id: result.id, criterion_id: mark.criterion_id,
                                        mark: 3.0 }, xhr: true
          expect(mark.reload.override).to be true
        end
        it 'sets override to true for mark if input value null and deductive annotations exist' do
          patch :update_mark, params: { course_id: course.id,
                                        id: result.id, criterion_id: mark.criterion_id,
                                        mark: '' }, xhr: true
          expect(mark.reload.override).to be true
        end
        it 'sets override to false for mark if input value null and only annotations with 0 value deduction exist' do
          assignment.annotation_categories.where.not(flexible_criterion: nil).first
                    .annotation_texts.first.update!(deduction: 0)
          patch :update_mark, params: { course_id: course.id,
                                        id: result.id, criterion_id: mark.criterion_id,
                                        mark: '' }, xhr: true
          expect(mark.reload.override).to be false
        end
      end
      it 'returns correct json fields when updating a mark' do
        patch :update_mark, params: { course_id: course.id,
                                      id: incomplete_result.id, criterion_id: rubric_mark.criterion_id,
                                      mark: '1', format: :json }, xhr: true
        expected_keys = %w[total subtotal mark_override num_marked mark]
        expect(response.parsed_body.keys.sort!).to eq(expected_keys.sort!)
      end
      it 'sets override to false for mark if input value null and no deductive annotations exist' do
        patch :update_mark, params: { course_id: course.id,
                                      id: incomplete_result.id, criterion_id: rubric_mark.criterion_id,
                                      mark: '', format: :json }, xhr: true
        expect(response.parsed_body['mark_override']).to be false
      end
      it { expect(response).to have_http_status(:redirect) }
      context 'but cannot save the mark' do
        before :each do
          allow_any_instance_of(Mark).to receive(:save).and_return false
          allow_any_instance_of(ActiveModel::Errors).to receive(:full_messages).and_return [SAMPLE_ERROR_MESSAGE]
          patch :update_mark, params: { course_id: course.id,
                                        id: incomplete_result.id, criterion_id: rubric_mark.criterion_id,
                                        mark: 1 }, xhr: true
        end
        it { expect(response).to have_http_status(:bad_request) }
        it 'should report the correct error message' do
          expect(response.body).to match SAMPLE_ERROR_MESSAGE
        end
      end
      context 'when duplicate marks exist' do
        # NOTE: this should not occur but it does happen because of concurrent requests and the fact that
        #       the find_or_create_by method is not atomic and neither are database writes
        let(:mark2) { build :mark, result: flexible_mark.result, criterion: flexible_mark.criterion }
        before do
          mark2.save(validate: false)
          patch :update_mark, params: { course_id: course.id,
                                        id: incomplete_result.id,
                                        criterion_id: flexible_mark.criterion_id,
                                        mark: 1 }, xhr: true
        end
        it 'should update the mark' do
          expect(flexible_mark.reload.mark).to eq 1
        end
        it 'should result in a valid mark' do
          expect(flexible_mark.reload).to be_valid
        end
        it 'should destroy the other duplicate mark' do
          expect { mark2.reload }.to raise_error(ActiveRecord::RecordNotFound)
        end
      end
    end
    context 'accessing view_mark' do
      before :each do
        get :view_marks, params: { course_id: course.id,
                                   id: incomplete_result.id }, xhr: true
      end
      it { expect(response).to have_http_status(:success) }
    end
    context 'accessing add_extra_mark' do
      context 'but cannot save the mark' do
        before :each do
          allow_any_instance_of(ExtraMark).to receive(:save).and_return false
          @old_mark = submission.get_latest_result.total_mark
          post :add_extra_mark, params: { course_id: course.id,
                                          id: submission.get_latest_result.id,
                                          extra_mark: { extra_mark: 1 } }, xhr: true
        end
        it { expect(response).to have_http_status(:bad_request) }
        it 'should not update the total mark' do
          expect(@old_mark).to eq(submission.get_latest_result.total_mark)
        end
      end
      context 'and can save the mark' do
        before :each do
          allow_any_instance_of(ExtraMark).to receive(:save).and_call_original
          @old_mark = submission.get_latest_result.total_mark
          post :add_extra_mark, params: { course_id: course.id,
                                          id: submission.get_latest_result.id,
                                          extra_mark: { extra_mark: 1 } }, xhr: true
        end
        it { expect(response).to have_http_status(:success) }
        it 'should update the total mark' do
          expect(@old_mark + 1).to eq(submission.get_latest_result.total_mark)
        end
      end
    end
    context 'accessing remove_extra_mark' do
      before :each do
        extra_mark = create(:extra_mark_points, result: submission.get_latest_result)
        submission.get_latest_result.update_total_mark
        @old_mark = submission.get_latest_result.total_mark
        delete :remove_extra_mark, params: { course_id: course.id,
                                             id: submission.get_latest_result.id,
                                             extra_mark_id: extra_mark.id }, xhr: true
      end
      test_no_flash
      it { expect(response).to have_http_status(:success) }
      it 'should change the total value' do
        submission.get_latest_result.update_total_mark
        expect(@old_mark).not_to eq incomplete_result.total_mark
      end
    end
    context 'accessing update_overall_comment' do
      before :each do
        post :update_overall_comment, params: { course_id: course.id,
                                                id: incomplete_result.id,
                                                result: { overall_comment: SAMPLE_COMMENT } }, xhr: true
        incomplete_result.reload
      end
      it { expect(response).to have_http_status(:success) }
      it 'should update the overall comment' do
        expect(incomplete_result.overall_comment).to eq SAMPLE_COMMENT
      end
    end

    context 'accessing an assignment with deductive annotations' do
      let(:assignment) { create(:assignment_with_deductive_annotations) }
      let(:mark) { assignment.groupings.first.current_result.marks.first }
      it 'returns annotation data with criteria information' do
        post :get_annotations, params: { course_id: course.id,
                                         id: assignment.groupings.first.current_result,
                                         format: :json }, xhr: true

        criterion = assignment.criteria.where(type: 'FlexibleCriterion').first
        expect(response.parsed_body.first['criterion_name']).to eq criterion.name
        expect(response.parsed_body.first['criterion_id']).to eq criterion.id
        expect(response.parsed_body.first['deduction']).to eq 1.0
      end

      it 'returns annotation_category data with deductive information' do
        category = assignment.annotation_categories.where.not(flexible_criterion: nil).first
        post :show, params: { course_id: course.id,
                              id: assignment.groupings.first.current_result,
                              format: :json }, xhr: true

        expect(response.parsed_body['annotation_categories'].first['annotation_category_name'])
          .to eq "#{category.annotation_category_name} [#{category.flexible_criterion.name}]"
        expect(response.parsed_body['annotation_categories'].first['texts'].first['deduction']).to eq 1.0
        expect(response.parsed_body['annotation_categories']
                   .first['flexible_criterion_id']).to eq category.flexible_criterion.id
      end

      it 'reverts a mark to a value calculated from automatic deductions correctly' do
        mark.update!(override: true, mark: 3.0)
        patch :revert_to_automatic_deductions, params: {
          course_id: course.id,
          id: assignment.groupings.first.current_result,
          criterion_id: mark.criterion_id,
          format: :json
        }, xhr: true

        mark.reload
        expect(mark.mark).to eq 2.0
        expect(mark.override).to be false
      end

      it 'returns correct information when reverting a mark to a value calculated from automatic deductions' do
        mark.update!(override: true, mark: 3.0)
        patch :revert_to_automatic_deductions, params: {
          course_id: course.id,
          id: assignment.groupings.first.current_result,
          criterion_id: mark.criterion_id,
          format: :json
        }, xhr: true

        expected_keys = %w[total subtotal num_marked mark]
        expect(response.parsed_body.keys.sort!).to eq(expected_keys.sort!)
      end
    end
  end

  shared_examples 'showing json data' do |is_student|
    let(:student2) do
      partner = create(:student, grace_credits: 2)
      create(:accepted_student_membership, role: partner, grouping: grouping)
      partner
    end
    subject do
      allow_any_instance_of(Result).to receive(:released_to_students?).and_return true
      get :show, params: { course_id: complete_result.course.id,
                           id: complete_result.id,
                           format: :json }
    end

    it 'contains important basic data' do
      subject
      expect(response.status).to eq(200)
      data = JSON.parse(response.body)
      received_data = {
        instructor_run: data['instructor_run'],
        is_reviewer: data['is_reviewer'],
        student_view: data['student_view'],
        can_run_tests: data['can_run_tests']
      }
      expected_data = {
        instructor_run: true,
        is_reviewer: false,
        student_view: is_student,
        can_run_tests: false
      }
      expect(received_data).to eq(expected_data)
    end

    it 'has submission file data' do
      subject
      data = JSON.parse(response.body)
      file_data = submission.submission_files.order(:path, :filename).pluck_to_hash(:id, :filename, :path)
      file_data.reject! { |f| Repository.get_class.internal_file_names.include? f[:filename] }
      expect(data['submission_files']).to eq(file_data)
    end

    it 'has no annotation categories data' do
      subject
      data = JSON.parse(response.body)
      expected_data = is_student ? be_nil : eq([])
      expect(data['annotation_categories']).to expected_data
    end

    it 'has no grace token deduction data' do
      subject
      data = JSON.parse(response.body)
      expect(data['grace_token_deductions']).to eq([])
    end

    context 'with grace token deductions' do
      let!(:grace_period_deduction1) do
        create :grace_period_deduction, membership: grouping.memberships.find_by(role: student)
      end
      let!(:grace_period_deduction2) do
        create :grace_period_deduction, membership: grouping.memberships.find_by(role: student2)
      end
      it 'sends grace token deduction data' do
        subject
        data = JSON.parse(response.body)
        expected_deduction_data = [
          {
            id: grace_period_deduction1.id,
            deduction: grace_period_deduction1.deduction,
            'users.user_name': student.user_name,
            'users.display_name': student.display_name
          }.stringify_keys
        ]
        unless is_student
          expected_deduction_data << {
            id: grace_period_deduction2.id,
            deduction: grace_period_deduction2.deduction,
            'users.user_name': student2.user_name,
            'users.display_name': student2.display_name
          }.stringify_keys
        end
        expect(data['grace_token_deductions']).to eq(expected_deduction_data)
      end
    end
  end

  ROUTES = { update_mark: :patch,
             edit: :get,
             download: :post,
             get_annotations: :get,
             add_extra_mark: :post,
             download_zip: :get,
             cancel_remark_request: :delete,
             delete_grace_period_deduction: :delete,
             next_grouping: :get,
             remove_extra_mark: :post,
             revert_to_automatic_deductions: :patch,
             set_released_to_students: :post,
             update_overall_comment: :post,
             toggle_marking_state: :post,
             update_remark_request: :patch,
             update_positions: :get,
             view_marks: :get,
             add_tag: :post,
             remove_tag: :post,
             run_tests: :post,
             stop_test: :get,
             get_test_runs_instructors: :get,
             get_test_runs_instructors_released: :get }.freeze

  context 'A student' do
    before(:each) { sign_in student }
    [:edit,
     :next_grouping,
     :set_released_to_students,
     :toggle_marking_state,
     :update_overall_comment,
     :update_mark,
     :add_extra_mark,
     :remove_extra_mark].each { |route_name| test_unauthorized(route_name) }
    context 'downloading files' do
      shared_examples 'without permission' do
        before :each do
          get :download, params: { course_id: course.id,
                                   id: incomplete_result.id,
                                   from_codeviewer: from_codeviewer,
                                   select_file_id: submission_file.id }
        end
        it { expect(response).to have_http_status(:forbidden) }
      end

      let(:assignment) { create :assignment_with_peer_review_and_groupings_results }
      let(:incomplete_result) { assignment.groupings.first.current_result }
      let(:submission) { incomplete_result.submission }
      context 'role is a reviewer for the current result' do
        let(:reviewer_grouping) { assignment.pr_assignment.groupings.first }
        let(:student) { reviewer_grouping.accepted_students.first }
        before { create :peer_review, reviewer: reviewer_grouping, result: incomplete_result }
        context 'from_codeviewer is true' do
          let(:from_codeviewer) { true }
          include_examples 'download files'
        end
        context 'from_codeviewer is nil' do
          include_examples 'without permission'
        end
      end
      context 'role is not a reviewer for the current result' do
        context 'role is an accepted member of the results grouping' do
          let(:student) { incomplete_result.grouping.accepted_students.first }
          context 'and the selected file is associated with the current submission' do
            let(:submission_file) { create(:submission_file, submission: incomplete_result.submission) }
            include_examples 'download files'
          end
          context 'and the selected file is associated with a different submission' do
            let(:submission_file) { create(:submission_file) }
            include_examples 'without permission'
          end
        end
        context 'role is not an accepted member of the results grouping' do
          let(:student) { create(:student) }
          include_examples 'without permission'
        end
      end
    end
    include_examples 'download files'
    include_examples 'showing json data', true
    context 'viewing a file' do
      context 'for a grouping with no submission' do
        before :each do
          allow_any_instance_of(Grouping).to receive(:has_submission?).and_return false
          get :view_marks, params: { course_id: course.id,
                                     id: incomplete_result.id }
        end
        it { expect(response).to render_template('results/student/no_submission') }
        it { expect(response).to have_http_status(:success) }
        test_assigns_not_nil :assignment
        test_assigns_not_nil :grouping
      end
      context 'for a grouping with a submission but no result' do
        before :each do
          allow_any_instance_of(Submission).to receive(:has_result?).and_return false
          get :view_marks, params: { course_id: course.id,
                                     id: incomplete_result.id }
        end
        it { expect(response).to render_template('results/student/no_result') }
        it { expect(response).to have_http_status(:success) }
        test_assigns_not_nil :assignment
        test_assigns_not_nil :grouping
        test_assigns_not_nil :submission
      end
      context 'for a grouping with an unreleased result' do
        before :each do
          allow_any_instance_of(Submission).to receive(:has_result?).and_return true
          allow_any_instance_of(Result).to receive(:released_to_students).and_return false
          get :view_marks, params: { course_id: course.id,
                                     id: incomplete_result.id }
        end
        it { expect(response).to render_template('results/student/no_result') }
        it { expect(response).to have_http_status(:success) }
        test_assigns_not_nil :assignment
        test_assigns_not_nil :grouping
        test_assigns_not_nil :submission
      end
      context 'and the result is available for viewing' do
        before :each do
          allow_any_instance_of(Submission).to receive(:has_result?).and_return true
          allow_any_instance_of(Result).to receive(:released_to_students).and_return true
          get :view_marks, params: { course_id: course.id,
                                     id: complete_result.id }
        end
        it { expect(response).to have_http_status(:success) }
        it { expect(response).to render_template(:view_marks) }
        test_assigns_not_nil :assignment
        test_assigns_not_nil :grouping
        test_assigns_not_nil :submission
        test_assigns_not_nil :result
        test_assigns_not_nil :annotation_categories
        test_assigns_not_nil :group
        test_assigns_not_nil :files
      end
    end
  end
  context 'An instructor' do
    before(:each) { sign_in instructor }

    context 'accessing set_released_to_students' do
      before :each do
        get :set_released_to_students, params: { course_id: course.id,
                                                 id: complete_result.id, value: 'true' }, xhr: true
      end
      it { expect(response).to have_http_status(:success) }
      test_assigns_not_nil :result
    end
    include_examples 'shared ta and instructor tests'
    include_examples 'showing json data', false

    describe '#delete_grace_period_deduction' do
      it 'deletes an existing grace period deduction' do
        expect(grouping.grace_period_deductions.exists?).to be false
        deduction = create(:grace_period_deduction,
                           membership: grouping.accepted_student_memberships.first,
                           deduction: 1)
        expect(grouping.grace_period_deductions.exists?).to be true
        delete :delete_grace_period_deduction,
               params: { course_id: course.id, id: complete_result.id, deduction_id: deduction.id }
        expect(grouping.grace_period_deductions.exists?).to be false
      end

      it 'raises a RecordNotFound error when given a grace period deduction that does not exist' do
        expect do
          delete :delete_grace_period_deduction,
                 params: { course_id: course.id, id: complete_result.id, deduction_id: 100 }
        end.to raise_error(ActiveRecord::RecordNotFound)
      end

      it 'raises a RecordNotFound error when given a grace period deduction for a different grouping' do
        student2 = create(:student, grace_credits: 2)
        grouping2 = create(:grouping_with_inviter, assignment: assignment, inviter: student2)
        submission2 = create(:version_used_submission, grouping: grouping2)
        create(:complete_result, submission: submission2)
        deduction = create(:grace_period_deduction,
                           membership: grouping2.accepted_student_memberships.first,
                           deduction: 1)
        expect do
          delete :delete_grace_period_deduction,
                 params: { course_id: course.id, id: complete_result.id, deduction_id: deduction.id }
        end.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
    describe '#add_tag' do
      it 'adds a tag to a grouping' do
        tag = create(:tag)
        post :add_tag,
             params: { course_id: course.id, id: complete_result.id, tag_id: tag.id }
        expect(complete_result.submission.grouping.tags.to_a).to eq [tag]
      end
    end

    describe '#remove_tag' do
      it 'removes a tag from a grouping' do
        tag = create(:tag)
        submission.grouping.tags << tag
        post :remove_tag,
             params: { course_id: course.id, id: complete_result.id, tag_id: tag.id }
        expect(complete_result.submission.grouping.tags.size).to eq 0
      end
    end

    describe 'when criteria are assigned to graders' do
      let(:assignment) { create(:assignment_with_deductive_annotations) }
      before(:each) { assignment.assignment_properties.update(assign_graders_to_criteria: true) }
      context 'when some criteria are assigned to graders' do
        it 'receives all deductive annotation category data' do
          helper_ta = create(:ta)
          first_category = assignment.annotation_categories.where.not(flexible_criterion_id: nil).first
          first_name = "#{first_category.annotation_category_name} [#{first_category.flexible_criterion.name}]"
          other_criterion = create(:flexible_criterion, assignment: assignment)
          assignment.groupings.each do |grouping|
            create(:flexible_mark, criterion: other_criterion, result: grouping.current_result)
          end
          create(:criterion_ta_association, criterion: other_criterion, ta: helper_ta)
          second_category = create(:annotation_category,
                                   assignment: assignment,
                                   flexible_criterion_id: other_criterion.id)
          second_name = "#{second_category.annotation_category_name} [#{second_category.flexible_criterion.name}]"
          post :show, params: { course_id: course.id,
                                id: assignment.groupings.first.current_result,
                                format: :json }, xhr: true

          category_names = [first_name, second_name].sort!
          returned_categories = response.parsed_body['annotation_categories'].map { |c| c['annotation_category_name'] }
          expect(returned_categories.sort!).to eq category_names
          expect(response.parsed_body['annotation_categories'].size).to eq 2
        end
      end

      context 'when none of the criteria are assigned to graders' do
        it 'receives all deductive annotation category data' do
          deductive_category = assignment.annotation_categories.where.not(flexible_criterion_id: nil).first
          cat_name = "#{deductive_category.annotation_category_name} [#{deductive_category.flexible_criterion.name}]"
          non_deductive_category = create(:annotation_category, assignment: assignment)
          post :show, params: { course_id: course.id,
                                id: assignment.groupings.first.current_result,
                                format: :json }, xhr: true

          category_names = [cat_name, non_deductive_category.annotation_category_name].sort!
          returned_categories = []
          response.parsed_body['annotation_categories'].each do |cat|
            returned_categories += [cat['annotation_category_name']]
          end
          expect(returned_categories.sort!).to eq category_names
          expect(response.parsed_body['annotation_categories'].size).to eq 2
          expect(response.parsed_body['annotation_categories'].select do |cat|
            cat['id'] == deductive_category.id
          end.size).to eq 1
        end
      end
    end
  end
  context 'A TA' do
    before(:each) { sign_in ta }
    [:set_released_to_students].each { |route_name| test_unauthorized(route_name) }
    context 'accessing edit' do
      before :each do
        get :edit, params: { course_id: course.id, id: incomplete_result.id }, xhr: true
      end
      test_no_flash
      it { expect(response).to render_template('edit') }
      it { expect(response).to have_http_status(:success) }
    end
    include_examples 'shared ta and instructor tests'
    include_examples 'showing json data', false

    context 'when groups information is anonymized' do
      let(:data) { JSON.parse(response.body) }
      let!(:grace_period_deduction) do
        create(:grace_period_deduction, membership: grouping.accepted_student_memberships.first)
      end
      before :each do
        assignment.assignment_properties.update(anonymize_groups: true)
        get :show, params: { course_id: course.id, id: incomplete_result.id }, xhr: true
      end

      it 'should anonymize the group names' do
        expect(data['group_name']).to eq "#{Group.model_name.human} #{data['grouping_id']}"
      end

      it 'should not include any group members' do
        expect(data['members']).to eq []
      end

      it 'should not report any grace token deductions' do
        expect(data['grace_token_deductions']).to eq []
      end
    end

    context 'when criteria are assigned to graders, but not this grader' do
      it 'receives no deductive annotation category data' do
        assignment = create(:assignment_with_deductive_annotations)
        assignment.assignment_properties.update(assign_graders_to_criteria: true)
        non_deductive_category = create(:annotation_category, assignment: assignment)
        post :show, params: { course_id: course.id,
                              id: assignment.groupings.first.current_result,
                              format: :json }, xhr: true

        expect(response.parsed_body['annotation_categories']
                       .first['annotation_category_name']).to eq non_deductive_category.annotation_category_name
        expect(response.parsed_body['annotation_categories'].size).to eq 1
      end
    end

    context 'when criteria are assigned to this grader' do
      let(:data) { JSON.parse(response.body) }
      let(:params) { { course_id: course.id, id: incomplete_result.id } }
      before :each do
        assignment.assignment_properties.update(assign_graders_to_criteria: true)
        create(:criterion_ta_association, criterion: rubric_mark.criterion, ta: ta)
        get :show, params: params, xhr: true
      end

      it 'should include assigned criteria list' do
        expect(data['assigned_criteria']).to eq [rubric_criterion.id]
      end

      context 'when accessing an assignment with deductive annotations' do
        let(:assignment) { create(:assignment_with_deductive_annotations) }
        it 'receives limited annotation category data when assigned '\
           'to a subset of criteria that have associated categories' do
          other_criterion = create(:flexible_criterion, assignment: assignment)
          assignment.groupings.each do |grouping|
            create(:flexible_mark, criterion: other_criterion, result: grouping.current_result)
          end
          assignment.assignment_properties.update(assign_graders_to_criteria: true)
          create(:criterion_ta_association, criterion: other_criterion, ta: ta)
          other_category = create(:annotation_category,
                                  assignment: assignment,
                                  flexible_criterion_id: other_criterion.id)
          post :show, params: { course_id: course.id,
                                id: assignment.groupings.first.current_result,
                                format: :json }, xhr: true
          expect(response.parsed_body['annotation_categories'].first['annotation_category_name'])
            .to eq "#{other_category.annotation_category_name} [#{other_category.flexible_criterion.name}]"
          expect(response.parsed_body['annotation_categories'].size).to eq 1
        end
      end

      context 'when unassigned criteria are hidden from the grader' do
        before :each do
          assignment.assignment_properties.update(hide_unassigned_criteria: true)
        end

        it 'should only include marks for the assigned criteria' do
          expected = [[rubric_criterion.class.to_s, rubric_criterion.id]]
          expect(data['marks'].map { |m| [m['criterion_type'], m['id']] }).to eq expected
        end

        context 'when a remark request exists' do
          let(:remarked_result) do
            incomplete_result.submission.make_remark_result
            incomplete_result.submission.update(remark_request_timestamp: Time.current)
            incomplete_result
          end
          let(:params) { { course_id: course.id, id: remarked_result.id } }

          it 'should only include marks for assigned criteria in the remark result' do
            expect(data['old_marks'].keys).to eq [rubric_criterion.id.to_s]
          end
        end
      end
    end

    context 'accessing update_mark' do
      it 'should not count completed groupings that are not assigned to the TA' do
        grouping2 = create(:grouping_with_inviter, assignment: assignment)
        create(:version_used_submission, grouping: grouping2)
        grouping2.current_result.update(marking_state: Result::MARKING_STATES[:complete])

        patch :update_mark, params: { course_id: course.id,
                                      id: incomplete_result.id, criterion_id: rubric_mark.criterion_id,
                                      mark: 1 }, xhr: true
        expect(JSON.parse(response.body)['num_marked']).to eq 0
      end
    end
    describe '#add_tag' do
      it 'adds a tag to a grouping' do
        tag = create(:tag)
        post :add_tag,
             params: { course_id: course.id, id: complete_result.id, tag_id: tag.id }
        expect(complete_result.submission.grouping.tags.to_a).to eq [tag]
      end
    end

    describe '#remove_tag' do
      it 'removes a tag from a grouping' do
        tag = create(:tag)
        submission.grouping.tags << tag
        post :remove_tag,
             params: { course_id: course.id, id: complete_result.id, tag_id: tag.id }
        expect(complete_result.submission.grouping.tags.size).to eq 0
      end
    end
  end
end
