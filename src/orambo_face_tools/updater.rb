# frozen_string_literal: true

require 'digest'
require 'fileutils'
require 'json'
require 'tmpdir'
require 'timeout'

module ORAMBO
  module FaceTools
    module Updater
      REPOSITORY = 'draleksei1-cmyk/ORAMBO-Face-Tools'
      RELEASES_API = "https://api.github.com/repos/#{REPOSITORY}/releases/latest"
      MANIFEST_NAME = 'update_manifest.json'
      PREFERENCE_SECTION = 'ORAMBO_Face_Tools'
      REQUEST_TIMEOUT = 20.0
      module_function

      def version_parts(version)
        normalized = version.to_s.sub(/\Av/i, '').split('-', 2).first
        raise ArgumentError, "Некорректная версия: #{version}" unless normalized.match?(/\A\d+\.\d+\.\d+\z/)
        normalized.split('.').map(&:to_i)
      end

      def newer_version?(candidate, installed)
        (version_parts(candidate) <=> version_parts(installed)).positive?
      end

      def manifest_url(release)
        return nil unless release.is_a?(Hash)
        return nil if release['draft'] || release['prerelease']
        asset = Array(release['assets']).find { |item| item['name'] == MANIFEST_NAME }
        url = asset && asset['browser_download_url'].to_s
        url && url.start_with?('https://') ? url : nil
      end

      def validate_path(path)
        value = path.to_s
        raise ArgumentError, 'Пустой путь обновления.' if value.empty?
        raise ArgumentError, "Недопустимый путь: #{value}" if value.include?('\\') || value.start_with?('/')
        segments = value.split('/')
        raise ArgumentError, "Недопустимый путь: #{value}" if segments.any? { |segment| segment.empty? || segment == '.' || segment == '..' }
        allowed = value == 'orambo_face_tools.rb' || value.start_with?('orambo_face_tools/')
        raise ArgumentError, "Путь вне расширения: #{value}" unless allowed
        value
      end

      def validate_manifest(json_or_hash)
        manifest = json_or_hash.is_a?(String) ? JSON.parse(json_or_hash) : json_or_hash
        raise ArgumentError, 'Manifest должен быть JSON-объектом.' unless manifest.is_a?(Hash)
        raise ArgumentError, 'Неизвестная схема manifest.' unless manifest['schema'] == 1
        version_parts(manifest['version'])
        unless manifest['restart_required'] == true || manifest['restart_required'] == false
          raise ArgumentError, 'restart_required должен быть true или false.'
        end
        files = manifest['files']
        raise ArgumentError, 'Manifest не содержит файлов.' unless files.is_a?(Array) && !files.empty?
        files.each do |entry|
          raise ArgumentError, 'Некорректная запись файла.' unless entry.is_a?(Hash)
          entry['path'] = validate_path(entry['path'])
          url = entry['url'].to_s
          raise ArgumentError, "Разрешены только HTTPS URL: #{url}" unless url.start_with?('https://')
          sha = entry['sha256'].to_s
          raise ArgumentError, "Некорректный SHA-256 для #{entry['path']}" unless sha.match?(/\A[0-9a-f]{64}\z/i)
          entry['sha256'] = sha.downcase
        end
        manifest
      rescue JSON::ParserError => error
        raise ArgumentError, "Некорректный JSON manifest: #{error.message}"
      end

      def verify_file(path, expected_sha256)
        return false unless File.file?(path)
        Digest::SHA256.file(path).hexdigest.casecmp?(expected_sha256.to_s)
      end

      def install_staged_files(staging_root, extension_root, entries, copier: nil)
        validated = entries.map do |entry|
          relative = validate_path(entry.fetch('path'))
          source = File.join(staging_root, relative)
          raise SecurityError, "SHA-256 не совпадает: #{relative}" unless verify_file(source, entry.fetch('sha256'))
          [relative, source]
        end
        default_copier = lambda do |source, destination, _index|
          FileUtils.cp(source, destination)
        end
        copy = copier || default_copier

        Dir.mktmpdir('orambo-face-tools-backup-') do |backup_root|
          existed = {}
          validated.each do |relative, _source|
            destination = destination_path(extension_root, relative)
            existed[relative] = File.file?(destination)
            next unless existed[relative]
            backup = File.join(backup_root, relative)
            FileUtils.mkdir_p(File.dirname(backup))
            FileUtils.cp(destination, backup)
          end

          begin
            validated.each_with_index do |(relative, source), index|
              destination = destination_path(extension_root, relative)
              FileUtils.mkdir_p(File.dirname(destination))
              copy.call(source, destination, index)
            end
          rescue Exception
            validated.reverse_each do |relative, _source|
              destination = destination_path(extension_root, relative)
              if existed[relative]
                backup = File.join(backup_root, relative)
                FileUtils.mkdir_p(File.dirname(destination))
                FileUtils.cp(backup, destination)
              else
                FileUtils.rm_f(destination)
              end
            end
            raise
          end
        end
        true
      end

      def destination_path(extension_root, relative)
        validated = validate_path(relative)
        root = File.expand_path(extension_root)
        destination = File.expand_path(validated, root)
        prefix = root.end_with?(File::SEPARATOR) ? root : root + File::SEPARATOR
        raise SecurityError, "Путь выходит за каталог расширения: #{relative}" unless destination.start_with?(prefix)
        destination
      end

      def reloadable_paths(entries)
        excluded = %w[orambo_face_tools.rb orambo_face_tools/main.rb orambo_face_tools/toolbar.rb]
        paths = entries.map { |entry| validate_path(entry.fetch('path')) }
                       .select { |path| path.end_with?('.rb') && !excluded.include?(path) }
        paths.sort_by do |path|
          basename = File.basename(path)
          priority = case basename
                     when 'utils.rb' then 0
                     when 'report.rb', 'progress.rb', 'safety.rb' then 1
                     when 'break_to_segments.rb', 'flatten_edges_to_z.rb', 'make_faces.rb' then 2
                     when 'updater.rb' then 9
                     else 5
                     end
          [priority, path]
        end
      end

      def reload_installed_files(extension_root, entries, loader: nil)
        load_file = loader || ->(path) { load(path) }
        reloadable_paths(entries).each do |relative|
          load_file.call(File.join(extension_root, relative))
        end
        true
      rescue LoadError, SyntaxError, StandardError => error
        log_error('Горячая перезагрузка не завершена; требуется перезапуск SketchUp.', error)
        false
      end

      def schedule_auto_check
        return if @auto_check_scheduled
        @auto_check_scheduled = true
        UI.start_timer(5.0, false) { check_for_updates(manual: false) }
      rescue StandardError => error
        log_error('Не удалось запланировать проверку обновлений', error)
      end

      def installed_version
        default = ORAMBO::FaceTools::EXTENSION_VERSION
        Sketchup.read_default(PREFERENCE_SECTION, 'runtime_version', default).to_s
      rescue StandardError
        ORAMBO::FaceTools::EXTENSION_VERSION
      end

      def check_for_updates(manual: false)
        http_get(RELEASES_API) do |status, body, error|
          if error || status != 200
            update_error("GitHub вернул HTTP #{status || 'ошибку сети'}.", manual, error)
            next
          end
          begin
            release = JSON.parse(body)
            url = manifest_url(release)
            raise 'В последнем Release нет update_manifest.json.' unless url
            candidate = release['tag_name'].to_s.sub(/\Av/i, '')
            unless newer_version?(candidate, installed_version)
              UI.messagebox("Установлена актуальная версия #{installed_version}.") if manual
              next
            end
            fetch_manifest(url, candidate, manual)
          rescue StandardError => parse_error
            update_error(parse_error.message, manual, parse_error)
          end
        end
      rescue StandardError => error
        update_error(error.message, manual, error)
      end

      def fetch_manifest(url, candidate, manual)
        http_get(url) do |status, body, error|
          if error || status != 200
            update_error("Не удалось скачать manifest: HTTP #{status || 'ошибка сети'}.", manual, error)
            next
          end
          begin
            manifest = validate_manifest(body)
            raise "Версия manifest #{manifest['version']} не совпадает с Release #{candidate}." unless manifest['version'] == candidate
            show_update_notification(manifest)
          rescue StandardError => manifest_error
            update_error(manifest_error.message, manual, manifest_error)
          end
        end
      end

      def http_get(url, &callback)
        request = Sketchup::Http::Request.new(url, Sketchup::Http::GET)
        request.headers = {
          'Accept' => 'application/vnd.github+json',
          'User-Agent' => "ORAMBO-Face-Tools/#{installed_version}"
        }
        @requests ||= []
        @requests << request
        timer = UI.start_timer(REQUEST_TIMEOUT, false) do
          if @requests.delete(request)
            request.cancel
            callback.call(nil, nil, Timeout::Error.new('HTTP timeout'))
          end
        end
        request.start do |_active_request, response|
          next unless @requests.delete(request)
          UI.stop_timer(timer) if UI.respond_to?(:stop_timer)
          callback.call(response.status_code, response.body, nil)
        rescue StandardError => error
          callback.call(nil, nil, error)
        end
        request
      rescue StandardError => error
        callback.call(nil, nil, error)
        nil
      end

      def show_update_notification(manifest)
        message = "Доступно обновление ORAMBO Face Tools #{manifest['version']}."
        if defined?(UI::Notification) && ORAMBO::FaceTools.const_defined?(:EXTENSION)
          notification = UI::Notification.new(ORAMBO::FaceTools::EXTENSION, message)
          notification.on_accept('Обновить') { install_update(manifest) }
          notification.on_dismiss('Позже') {}
          notification.show
          keep_notification(notification)
        else
          answer = UI.messagebox("#{message}\n\nУстановить сейчас?", MB_YESNO)
          install_update(manifest) if answer == IDYES
        end
      end

      def install_update(manifest)
        staging = Dir.mktmpdir('orambo-face-tools-update-')
        entries = manifest.fetch('files')
        download_file(entries, 0, staging, manifest)
      rescue StandardError => error
        update_error("Обновление не установлено: #{error.message}", true, error)
        FileUtils.rm_rf(staging) if staging
      end

      def download_file(entries, index, staging, manifest)
        if index >= entries.length
          apply_downloaded_update(staging, manifest)
          return
        end
        entry = entries[index]
        http_get(entry['url']) do |status, body, error|
          if error || status != 200
            FileUtils.rm_rf(staging)
            update_error("Не удалось скачать #{entry['path']}: HTTP #{status || 'ошибка сети'}.", true, error)
            next
          end
          begin
            path = File.join(staging, validate_path(entry['path']))
            FileUtils.mkdir_p(File.dirname(path))
            File.binwrite(path, body)
            raise "SHA-256 не совпадает: #{entry['path']}" unless verify_file(path, entry['sha256'])
            download_file(entries, index + 1, staging, manifest)
          rescue StandardError => file_error
            FileUtils.rm_rf(staging)
            update_error("Обновление отменено: #{file_error.message}", true, file_error)
          end
        end
      end

      def apply_downloaded_update(staging, manifest)
        root = File.dirname(__dir__)
        install_staged_files(staging, root, manifest['files'])
        Sketchup.write_default(PREFERENCE_SECTION, 'runtime_version', manifest['version'])
        if manifest['restart_required']
          notify_result('Обновление установлено. Перезапустите SketchUp для применения изменений интерфейса.')
        else
          if reload_installed_files(root, manifest['files'])
            notify_result("Обновление #{manifest['version']} применено без перезапуска SketchUp.")
          else
            notify_result('Файлы обновлены, но горячая перезагрузка не завершена. Перезапустите SketchUp.')
          end
        end
      rescue StandardError => error
        update_error("Не удалось применить обновление: #{error.message}", true, error)
      ensure
        FileUtils.rm_rf(staging) if staging
      end

      def notify_result(message)
        if defined?(UI::Notification) && ORAMBO::FaceTools.const_defined?(:EXTENSION)
          notification = UI::Notification.new(ORAMBO::FaceTools::EXTENSION, message)
          notification.show
          keep_notification(notification)
        else
          UI.messagebox(message)
        end
      end

      def keep_notification(notification)
        @notifications ||= []
        @notifications << notification
        @notifications.shift while @notifications.length > 5
      end

      def update_error(message, manual, error = nil)
        log_error(message, error)
        UI.messagebox("ORAMBO Face Tools\n\n#{message}") if manual
      end

      def log_error(message, error = nil)
        puts("[ORAMBO Face Tools Updater] #{message}")
        puts(error.full_message) if error && error.respond_to?(:full_message)
      end
    end
  end
end
