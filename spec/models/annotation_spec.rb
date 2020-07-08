describe Annotation do
  context 'checks relationships' do
    it { is_expected.to belong_to(:submission_file) }
    it { is_expected.to belong_to(:annotation_text) }
    it { is_expected.to belong_to(:result) }
  end

  context 'requires items to be set' do
    it { is_expected.to validate_presence_of(:annotation_number) }
  end

  context 'validates certain values' do
    it { is_expected.to validate_numericality_of(:annotation_number) }
  end

  context 'ensures invalid values cannot be added' do
    it { is_expected.to_not allow_value(-1).for(:annotation_number) }

    it { is_expected.to allow_value('ImageAnnotation').for(:type) }
    it { is_expected.to allow_value('TextAnnotation').for(:type) }
    it { is_expected.to allow_value('PdfAnnotation').for(:type) }
    it { is_expected.to_not allow_value('OtherAnnotation').for(:type) }
  end

  context 'when associated with a deduction' do
    let(:assignment) { create(:assignment_with_deductive_annotations) }
    let(:annotation_category) { assignment.annotation_categories.where.not(flexible_criterion_id: nil).first }
    let(:annotation_text) { annotation_category.annotation_texts.first }
    let(:result) { assignment.groupings.first.current_result }
    let(:mark) { result.marks.find_by(markable_id: annotation_category.flexible_criterion_id) }

    it 'correctly updates the mark when created' do
      create(:text_annotation,
             annotation_text: annotation_text,
             result: result)
      expect(mark.mark).to eq 1.0
    end

    it 'correctly updates the mark when destroyed, being only deductive annotation applied' do
      result.annotations.find_by(annotation_text: annotation_text).destroy
      expect(mark.mark).to eq nil
    end

    it 'correctly updates the mark when destroyed, being one of several deductive annotations applied' do
      create(:text_annotation,
             annotation_text: annotation_text,
             result: result)
      result.annotations.find_by(annotation_text: annotation_text).destroy
      expect(mark.mark).to eq 2.0
    end

    it 'correctly updates the mark for its criterion\'s mark when a different type of criterion has the same id' do
      other_f_c = create(:flexible_criterion_with_annotation_category, id: 5, assignment: assignment)
      create(:rubric_criterion, id: 5, assignment: assignment)
      other_a_c = other_f_c.annotation_categories.first
      create(:flexible_mark,
             markable_id: 5,
             result: result)
      create(:rubric_mark,
             markable_id: 5,
             result: result)
      create(:text_annotation,
             annotation_text: other_a_c.annotation_texts.first,
             result: result)
      result.reload
      flex_mark = result.marks.find_by(markable_id: 5, markable_type: 'FlexibleCriterion')
      expect(flex_mark.mark).to eq 2.0
    end
  end
end
