#!/usr/bin/env ruby
# Assign the prepared creative assets without withdrawing any app submission.
require 'spaceship'
require 'json'
root = File.expand_path('../..', __dir__)
path = File.join(root, 'fastlane/creative/upload-state.json')
state = JSON.parse(File.read(path))
Spaceship::ConnectAPI.login(ENV.fetch('FASTLANE_APPLE_ID'), nil, use_portal: false, tunes_team_id: ENV['FASTLANE_ITC_TEAM_ID'])
c = Spaceship::ConnectAPI.client.tunes_request_client
app = Spaceship::ConnectAPI::App.find('com.tabletbasic.app') or abort 'TabletBasic not found'
expected = { 'header' => '1eb43b80-e0b7-4d96-bd32-47a42a8c5fed', 'search_results' => 'd2ffa3b7-6c55-5cdf-8512-229d92791333' }
ready = true
state['assets'].each do |key, asset|
  a = c.get("v1/appAssetLibraryImages/#{asset['id']}").body.fetch('data').fetch('attributes')
  asset['state'] = a['state']; asset['spec_id'] = a['specId']
  puts "#{key}: #{a['state']}, spec=#{a['specId']}, details=#{a['stateDetails']}"
  ready = false unless %w[PREPARE_FOR_SUBMISSION READY_FOR_REVIEW WAITING_FOR_REVIEW IN_REVIEW ACCEPTED APPROVED].include?(a['state'])
  abort "Unexpected specification for #{key}" if a['specId'] && a['specId'] != expected[key]
end
File.write(path, JSON.pretty_generate(state) + "\n")
exit 2 unless ready

target_version = ENV.fetch('APP_STORE_CREATIVE_VERSION', '1.1.0')
version = app.get_app_store_versions.find { |v| v.version_string == target_version }
abort "Version #{target_version} not found" unless version
localization = version.get_app_store_version_localizations.find { |l| l.locale == 'en-US' }
abort 'en-US localization missing' unless localization
placements = c.get("v1/appStoreVersionLocalizations/#{localization.id}/placements", { filter: { placementGroup: 'DEFAULT_PROFILE' } }).body.fetch('data')
state['assets'].each do |key, asset|
  existing = placements.find { |p| p.dig('attributes', 'placementType') == asset['placement_type'] }
  if existing
    abort "#{key} already uses another image; refusing to replace it" unless existing.dig('relationships', 'image', 'data', 'id') == asset['id']
    asset['placement_id'] = existing['id']
    next
  end
  begin
    p = c.post('v1/appAssetLibraryPlacements', { data: { type: 'appAssetLibraryPlacements', attributes: {
      placementType: asset['placement_type'], placementGroup: 'DEFAULT_PROFILE'
    }, relationships: {
      image: { data: { type: 'appAssetLibraryImages', id: asset['id'] } },
      appStoreVersionLocalization: { data: { type: 'appStoreVersionLocalizations', id: localization.id } }
    } } }, tries: 1).body.fetch('data')
    asset['placement_id'] = p['id']
    asset['placement_state'] = p.dig('attributes', 'state')
    puts "#{key}: placed on #{target_version}, #{asset['placement_state']}"
  rescue Spaceship::UnexpectedResponse => e
    puts "Placement unavailable: #{e.message}"
    state['placement_blocker'] = e.message
    File.write(path, JSON.pretty_generate(state) + "\n")
    exit 3
  end
  File.write(path, JSON.pretty_generate(state) + "\n")
end
