#!/usr/bin/env ruby
# Submit marketing artwork separately, without canceling the app version review.
require 'spaceship'
require 'json'
root = File.expand_path('../..', __dir__)
path = File.join(root, 'fastlane/creative/upload-state.json')
state = JSON.parse(File.read(path))
Spaceship::ConnectAPI.login(ENV.fetch('FASTLANE_APPLE_ID'), nil, use_portal: false, tunes_team_id: ENV['FASTLANE_ITC_TEAM_ID'])
c = Spaceship::ConnectAPI.client.tunes_request_client
state['assets'].each do |key, asset|
  attrs = c.get("v1/appAssetLibraryImages/#{asset['id']}").body.fetch('data').fetch('attributes')
  asset['state'] = attrs['state']; asset['spec_id'] = attrs['specId']
  puts "#{key}: #{attrs['state']}"
  unless %w[PREPARE_FOR_SUBMISSION READY_FOR_REVIEW WAITING_FOR_REVIEW IN_REVIEW ACCEPTED APPROVED].include?(attrs['state'])
    File.write(path, JSON.pretty_generate(state) + "\n")
    abort 'Artwork is not ready for review; wait for Apple processing and retry.'
  end
end
unless state['review_submission_id']
  data = c.post('v1/reviewSubmissions', { data: { type: 'reviewSubmissions', relationships: {
    app: { data: { type: 'apps', id: state.fetch('app_id') } }
  } } }, tries: 1).body.fetch('data')
  state['review_submission_id'] = data.fetch('id')
  File.write(path, JSON.pretty_generate(state) + "\n")
end
id = state.fetch('review_submission_id')
submission = c.get("v1/reviewSubmissions/#{id}").body.fetch('data')
if submission.dig('attributes', 'state') == 'READY_FOR_REVIEW'
  state['assets'].each do |key, asset|
    next if asset['review_item_id']
    data = c.post('v1/reviewSubmissionItems', { data: { type: 'reviewSubmissionItems', relationships: {
      reviewSubmission: { data: { type: 'reviewSubmissions', id: id } },
      appAssetLibraryImage: { data: { type: 'appAssetLibraryImages', id: asset.fetch('id') } }
    } } }, tries: 1).body.fetch('data')
    asset['review_item_id'] = data.fetch('id')
    File.write(path, JSON.pretty_generate(state) + "\n")
  end
  c.patch("v1/reviewSubmissions/#{id}", { data: { type: 'reviewSubmissions', id: id, attributes: { submitted: true } } })
end
submission = c.get("v1/reviewSubmissions/#{id}").body.fetch('data')
state['review_state'] = submission.dig('attributes', 'state')
File.write(path, JSON.pretty_generate(state) + "\n")
puts "Creative review: #{state['review_state']} (#{id})"
