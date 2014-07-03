require 'encoding'

class AnnotationCategoriesController < ApplicationController
  include AnnotationCategoriesHelper

  before_filter      :authorize_only_for_admin

  def index
    @assignment = Assignment.find(params[:assignment_id])
    @annotation_categories = @assignment.annotation_categories(order: 'position')
  end

  def get_annotations
    @annotation_category = AnnotationCategory.find(params[:id])
    @annotation_texts = @annotation_category.annotation_texts
  end

  def add_annotation_category
    @assignment = Assignment.find(params[:assignment_id])
    if request.post?
      # Attempt to add Annotation Category
      @annotation_categories = @assignment.annotation_categories
      if @annotation_categories.length > 0
        new_position = @annotation_categories.last.position + 1
      else
        new_position = 1
      end
      @annotation_category = AnnotationCategory.new
      @annotation_category.update_attributes(params[:annotation_category])
      @annotation_category.assignment = @assignment
      @annotation_category.position = new_position
      unless @annotation_category.save
        render :new_annotation_category_error
        return
      end
      render :insert_new_annotation_category
    end
  end

  def update_annotation_category
    @assignment = Assignment.find(params[:assignment_id])
    @annotation_category = AnnotationCategory.find(params[:id])

    @annotation_category.update_attributes(params[:annotation_category])
    if @annotation_category.save
      flash.now[:success] = I18n.t('annotations.update.annotation_category_success')
    else
      flash.now[:error] = @annotation_category.errors.full_messages
    end
  end

  def update_annotation
    @annotation_text = AnnotationText.find(params[:id])
    @annotation_text.update_attributes(params[:annotation_text])
    @annotation_text.last_editor_id = current_user.id
    @annotation_text.save
  end

  def add_annotation_text
    @annotation_category = AnnotationCategory.find(params[:id])
    if request.post?
      # Attempt to add Annotation Text
      @annotation_text = AnnotationText.new
      @annotation_text.update_attributes(params[:annotation_text])
      @annotation_text.annotation_category = @annotation_category
      @annotation_text.creator_id = current_user.id
      @annotation_text.last_editor_id = current_user.id
      unless @annotation_text.save
        render :new_annotation_text_error
        return
      end
      @assignment = Assignment.find(params[:assignment_id])
      render :insert_new_annotation_text
    end
  end

  def delete_annotation_text
    @assignment = Assignment.find(params[:assignment_id])
    @annotation_text = AnnotationText.find(params[:id])
    @annotation_text.destroy
  end

  def delete_annotation_category
    @annotation_category = AnnotationCategory.find(params[:id])
    @annotation_category.destroy
  end

  # This method handles the drag/drop Annotations sorting
  def update_positions
    unless request.post?
      render nothing: true
      return
    end

    @assignment = Assignment.find(params[:assignment_id])
    @annotation_categories = @assignment.annotation_categories
    position = 0

    params[:annotation_category].each do |id|
      if id != ''
        position += 1
        AnnotationCategory.update(id, position: position)
      end
    end
  end

  def download
    @assignment = Assignment.find(params[:assignment_id])
    @annotation_categories = @assignment.annotation_categories
    case params[:format]
    when 'csv'
      send_data convert_to_csv(@annotation_categories),
                filename: "#{@assignment.short_identifier}_annotations.csv",
                disposition: 'attachment'
    when 'yml'
      send_data convert_to_yml(@annotation_categories),
                filename: "#{@assignment.short_identifier}_annotations.yml",
                disposition: 'attachment'
    else
      flash[:error] = I18n.t('annotations.upload.flash_error',
        format: params[:format])
      redirect_to action: 'index',
                  id: params[:id]
    end
  end

  def csv_upload
    @assignment = Assignment.find(params[:assignment_id])
    encoding = params[:encoding]
    unless request.post?
      redirect_to action: 'index', id: @assignment.id
      return
    end
    annotation_category_list = params[:annotation_category_list_csv]
    annotation_category_number = 0
    annotation_line = 0
    if annotation_category_list
      annotation_category_list = annotation_category_list.utf8_encode(encoding)
      CSV.parse(annotation_category_list) do |row|
        next if CSV.generate_line(row).strip.empty?
        annotation_line += 1
        result = AnnotationCategory.add_by_row(row, @assignment, current_user)
        if result[:annotation_upload_invalid_lines].size > 0
          flash[:error] = I18n.t('annotations.upload.error',
            annotation_category: row, annotation_line: annotation_line)
          break
        else
          annotation_category_number += 1
        end
      end
      if annotation_category_number > 0
        flash[:success] = I18n.t('annotations.upload.success',
          annotation_category_number: annotation_category_number)
      end
    end
    redirect_to action: 'index', id: @assignment.id
  end

  def yml_upload
    @assignment = Assignment.find(params[:assignment_id])
    encoding = params[:encoding]
    unless request.post?
      redirect_to action: 'index', assignment_id: @assignment.id
      return
    end
    file = params[:annotation_category_list_yml]
    annotation_category_number = 0
    annotation_line = 0
    unless file.blank?
      begin
        annotations = YAML::load(file.utf8_encode(encoding))
      # ArgumentError is thrown by Syck in Ruby 1.* whereas Psych::SyntaxError
      # is thrown by Psych in Ruby 2.*.
      rescue ArgumentError, Psych::SyntaxError => e
        flash[:error] = I18n.t('annotations.upload.syntax_error',
          error: "#{e}")
        redirect_to action: 'index', assignment_id: @assignment.id
        return
      end
      annotations.each_key do |key|
      result = AnnotationCategory.add_by_array(key, annotations.values_at(key), @assignment, current_user)
      annotation_line += 1
      if result[:annotation_upload_invalid_lines].size > 0
        flash[:error] = I18n.t('annotations.upload.error',
          annotation_category: key, annotation_line: annotation_line)
        break
      else
        annotation_category_number += 1
      end
     end
     if annotation_category_number > 0
        flash[:success] = I18n.t('annotations.upload.success',
          annotation_category_number: annotation_category_number)
     end
    end
    redirect_to action: 'index', assignment_id: @assignment.id
  end
end
