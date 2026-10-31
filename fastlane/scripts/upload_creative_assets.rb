#!/usr/bin/env ruby
# App Asset Library API: https://developer.apple.com/documentation/appstoreconnectapi/app-asset-library
require 'spaceship'
require 'json'
require 'digest'

root = File.expand_path('../..', __dir__)
state_path = File.join(root, 'fastlane/creative/upload-state.json')
state = File.exist?(state_path) ? JSON.parse(File.read(state_path)) : { 'assets' => {} }
user = ENV.fetch('FASTLANE_APPLE_ID')
Spaceship::ConnectAPI.login(user, nil, use_portal: false, tunes_team_id: ENV['FASTLANE_ITC_TEAM_ID'])
c = Spaceship::ConnectAPI.client.tunes_request_client
app = Spaceship::ConnectAPI::App.find('com.tabletbasic.app') or abort 'TabletBasic not found'
library = c.get("v1/apps/#{app.id}/assetLibrary").body.fetch('data').fetch('id')
assets = {
  'header' => ['tabletbasic-header-v1.png', 'TabletBasic — Hello, World — Header', 'PRODUCT_PAGE_HEADER_ASSET'],
  'search_results' => ['tabletbasic-search-results-v1.png', 'TabletBasic — Learn BASIC — Search', 'APP_STORE_SEARCH_RESULTS_ASSET']
}

def persist(path, state)
  File.write(path, JSON.pretty_generate(state) + "\n")
end

assets.each do |key, (filename, reference_name, placement_type)|
  file = File.join(root, 'fastlane/creative/en-US', filename)
  bytes = File.binread(file)
  digest = Digest::SHA256.hexdigest(bytes)
  previous = state['assets'][key]
  if previous
    abort "#{filename} changed after upload; create a new versioned filename" unless previous['sha256'] == digest
    id = previous['id']
  else
    reservation = c.post('v1/appAssetLibraryImages', {
      data: { type: 'appAssetLibraryImages',
        attributes: { fileName: filename, fileSize: bytes.bytesize, category: 'CREATIVE_ASSETS', referenceName: reference_name },
        relationships: { assetLibrary: { data: { type: 'appAssetLibraries', id: library } } } }
    }).body.fetch('data')
    id = reservation.fetch('id')
    state['assets'][key] = { 'id' => id, 'filename' => filename, 'sha256' => digest, 'placement_type' => placement_type, 'uploaded' => false }
    persist(state_path, state)
  end
  asset = c.get("v1/appAssetLibraryImages/#{id}").body.fetch('data')
  if asset.fetch('attributes')['state'] == 'AWAITING_UPLOAD'
    operations = asset.fetch('attributes').fetch('uploadOperations')
    Spaceship::ConnectAPI::FileUploader.upload(operations, bytes)
    c.patch("v1/appAssetLibraryImages/#{id}", { data: { type: 'appAssetLibraryImages', id: id, attributes: { uploaded: true } } })
  end
  state['assets'][key]['uploaded'] = true
  persist(state_path, state)
  puts "#{key}: uploaded #{id}"
end

state['app_id'] = app.id
state['library_id'] = library
persist(state_path, state)
state['assets'].each do |key, asset|
  data = c.get("v1/appAssetLibraryImages/#{asset['id']}").body.fetch('data')
  attrs = data.fetch('attributes')
  asset['state'] = attrs['state']
  asset['spec_id'] = attrs['specId']
  puts "#{key}: #{asset['state']}, spec=#{asset['spec_id']}, details=#{attrs['stateDetails']}"
end
persist(state_path, state)
puts JSON.pretty_generate(app.get_app_store_versions.map { |v| { id: v.id, version: v.version_string, state: v.app_store_state } })
