require 'digest/md5'
module ActiveRecord
  class Migrator
    class << self

      def check_concordance
        case differs = self.current_differs_from_snapshot("db/migrate")
        when false
          "***** DB schema is in sync with migrations."
        when 0
          "***** DB schema state unknown. No migration snapshot to compare."
        else
          "***** DB schema needs to be migrated from: #{differs}"
        end
      end

      def migrate_with_snapshot(migrations_path, target_version = nil)
        if migrations_path =~ %r{vendor/plugins}
          migrate_without_snapshot(migrations_path, target_version)
        else
          old_version = current_version rescue nil
          migrate_without_snapshot(migrations_path, target_version)
          if current_version != old_version
            snapshot = generate_snapshot(migrations_path)
            lines = YAML.dump(snapshot).split("\n").sort
            File.open(snapshot_path, "w") { |f| f.puts(lines) }
          end
        end
      end
      alias_method_chain :migrate, :snapshot

      def current_differs_from_snapshot(migrations_path)
        if File.exists?(snapshot_path)
          current = generate_snapshot(migrations_path)
          snapshot = YAML.load_file(snapshot_path)
          diff = current.diff(snapshot) 
          diff.keys.empty? ? false : diff.keys.sort.first
        else
          0
        end
      end

      def generate_snapshot(migrations_path)
        files = Dir[File.join(migrations_path, "[0-9]*_*.rb")].collect { |n| File.basename(n) }
        snapshot = {}
        files.each do |file|
          snapshot[File.basename(file, ".rb")] = Digest::MD5.hexdigest(File.read(File.join(migrations_path, file)))
        end
        snapshot
      end

      def snapshot_path
        File.join(RAILS_ROOT, "db", "migration_snapshot.yml")
      end

    end
  end
end
