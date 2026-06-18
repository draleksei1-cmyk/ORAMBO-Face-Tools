# frozen_string_literal: true

require_relative 'test_helper'
require 'digest'
require 'fileutils'
require 'json'
require 'tmpdir'
require_relative '../src/orambo_face_tools/updater'

class UpdaterTest < Minitest::Test
  U = ORAMBO::FaceTools::Updater

  def test_semver_comparison_is_numeric
    assert U.newer_version?('0.1.10', '0.1.9')
    refute U.newer_version?('0.1.0', '0.1.0')
    refute U.newer_version?('0.1.0', '0.2.0')
  end

  def test_manifest_url_uses_named_release_asset
    release = {
      'draft' => false, 'prerelease' => false,
      'assets' => [
        { 'name' => 'plugin.rbz', 'browser_download_url' => 'https://example/plugin.rbz' },
        { 'name' => 'update_manifest.json', 'browser_download_url' => 'https://example/update_manifest.json' }
      ]
    }
    assert_equal 'https://example/update_manifest.json', U.manifest_url(release)
  end

  def test_manifest_url_rejects_prerelease
    assert_nil U.manifest_url('prerelease' => true, 'draft' => false, 'assets' => [])
  end

  def test_manifest_url_rejects_insecure_asset
    release = {
      'draft' => false, 'prerelease' => false,
      'assets' => [{ 'name' => 'update_manifest.json', 'browser_download_url' => 'http://example/manifest.json' }]
    }
    assert_nil U.manifest_url(release)
  end

  def test_paths_cannot_escape_extension_root
    assert_equal 'orambo_face_tools/updater.rb', U.validate_path('orambo_face_tools/updater.rb')
    assert_equal 'orambo_face_tools.rb', U.validate_path('orambo_face_tools.rb')
    ['../evil.rb', '/absolute.rb', 'orambo_face_tools/../../evil.rb', 'other/file.rb', 'orambo_face_tools\\evil.rb'].each do |path|
      assert_raises(ArgumentError) { U.validate_path(path) }
    end
  end

  def test_manifest_validation_requires_https_and_sha256
    manifest = manifest_for('orambo_face_tools/updater.rb', 'https://example/updater.rb', 'a' * 64)
    validated = U.validate_manifest(JSON.generate(manifest))
    assert_equal '0.1.1', validated.fetch('version')

    manifest['files'][0]['url'] = 'http://example/updater.rb'
    assert_raises(ArgumentError) { U.validate_manifest(JSON.generate(manifest)) }
    manifest['files'][0]['url'] = 'https://example/updater.rb'
    manifest['files'][0]['sha256'] = 'short'
    assert_raises(ArgumentError) { U.validate_manifest(JSON.generate(manifest)) }
  end

  def test_hash_verification
    Dir.mktmpdir do |directory|
      path = File.join(directory, 'file.rb')
      File.binwrite(path, 'new code')
      assert U.verify_file(path, Digest::SHA256.hexdigest('new code'))
      refute U.verify_file(path, '0' * 64)
    end
  end

  def test_transaction_replaces_all_files
    with_install_fixture do |root, stage, entries|
      U.install_staged_files(stage, root, entries)
      assert_equal 'new one', File.binread(File.join(root, entries[0]['path']))
      assert_equal 'new two', File.binread(File.join(root, entries[1]['path']))
    end
  end

  def test_transaction_rolls_back_every_file_on_failure
    with_install_fixture do |root, stage, entries|
      copier = lambda do |source, destination, index|
        raise IOError, 'forced copy failure' if index == 1
        FileUtils.cp(source, destination)
      end
      assert_raises(IOError) { U.install_staged_files(stage, root, entries, copier: copier) }
      assert_equal 'old one', File.binread(File.join(root, entries[0]['path']))
      assert_equal 'old two', File.binread(File.join(root, entries[1]['path']))
    end
  end

  def test_reload_order_excludes_registration_files_and_updates_updater_last
    entries = %w[
      orambo_face_tools.rb
      orambo_face_tools/main.rb
      orambo_face_tools/toolbar.rb
      orambo_face_tools/make_faces.rb
      orambo_face_tools/utils.rb
      orambo_face_tools/updater.rb
      orambo_face_tools/icons/make_faces_16.png
    ].map { |path| { 'path' => path } }
    assert_equal %w[orambo_face_tools/utils.rb orambo_face_tools/make_faces.rb orambo_face_tools/updater.rb],
                 U.reloadable_paths(entries)
  end

  def test_reload_failure_returns_false_instead_of_claiming_update_failed
    entries = [{ 'path' => 'orambo_face_tools/utils.rb' }, { 'path' => 'orambo_face_tools/make_faces.rb' }]
    loaded = []
    loader = lambda do |path|
      loaded << File.basename(path)
      raise LoadError, 'bad reload' if path.end_with?('make_faces.rb')
    end
    result = nil
    capture_io { result = U.reload_installed_files('C:/plugin-root', entries, loader: loader) }
    refute result
    assert_equal %w[utils.rb make_faces.rb], loaded
  end

  private

  def manifest_for(path, url, sha)
    {
      'schema' => 1,
      'version' => '0.1.1',
      'restart_required' => false,
      'files' => [{ 'path' => path, 'url' => url, 'sha256' => sha }]
    }
  end

  def with_install_fixture
    Dir.mktmpdir do |root|
      Dir.mktmpdir do |stage|
        paths = %w[orambo_face_tools/one.rb orambo_face_tools/two.rb]
        paths.each do |relative|
          FileUtils.mkdir_p(File.dirname(File.join(root, relative)))
          FileUtils.mkdir_p(File.dirname(File.join(stage, relative)))
        end
        File.binwrite(File.join(root, paths[0]), 'old one')
        File.binwrite(File.join(root, paths[1]), 'old two')
        File.binwrite(File.join(stage, paths[0]), 'new one')
        File.binwrite(File.join(stage, paths[1]), 'new two')
        entries = [
          { 'path' => paths[0], 'sha256' => Digest::SHA256.hexdigest('new one') },
          { 'path' => paths[1], 'sha256' => Digest::SHA256.hexdigest('new two') }
        ]
        yield root, stage, entries
      end
    end
  end
end
