require 'spec_helper'

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
    it { should_not allow_value(-1).for(:annotation_number) }

    it { should allow_value('ImageAnnotation').for(:type) }
    it { should allow_value('TextAnnotation').for(:type) }
    it { should_not allow_value('OtherAnnotation').for(:type) }
  end
end
