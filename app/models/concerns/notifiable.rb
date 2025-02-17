# frozen_string_literal: true

module Notifiable
  def notify_for(events, check: nil)
    events.each do |action|
      send "after_#{action}" do |model|
        model.notifiable_callable(check, action)
      end
    end
  end

  def notifiable_callable(check, action)
    return if !check.nil? && !send(check)

    NotificationSetupWorker.perform_async(
      NotificationEvent.new(notifiable_name, id, action, notifiable_attrs, updates).to_json
    )
  end

  private

  def notifiable_attrs
    if respond_to? :notification_attributes
      notification_attributes
    else
      attributes
    end
  end

  def updates
    saved_changes.reject do |k, _v|
      %w[updated_at last_activity_at].include?(k)
    end.map do |key, values| # rubocop:disable Style/MultilineBlockChain
      { key => {
        old: values[0],
        new: values[1]
      } }
    end
  end

  def notifiable_name
    if respond_to?(:notifiable_name)
      notifiable_name
    else
      self.class.name.downcase
    end
  end
end
