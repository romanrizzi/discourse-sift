shared_examples 'It notifies users when the setting is enabled' do
  it 'Notifies user if the setting is enabled' do
    SiteSetting.sift_notify_user = true

    SystemMessage.expects(:create).with(post.user, sift_reason, topic_title: post.topic.title).once

    perform_action
  end

  it 'Does nothing when the setting is disabled' do
    SiteSetting.sift_notify_user = false

    SystemMessage.expects(:create).never

    perform_action
  end
end
