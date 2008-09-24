require 'digest/md5'

module MCColor
  COLORS = { :clear => 0, :red => 31, :green => 32, :yellow => 33 }
  def self.color(color)
    "\e[#{COLORS[color.to_sym]}m"
  end
  def self.colorize(color_name, str)
    color(color_name) + str + color(:clear)
  end
  def self.red(str);      colorize(:red, str);      end
  def self.green(str);    colorize(:green, str);    end
  def self.yellow(str);   colorize(:yellow, str);   end
end

unless ENV['TM_MODE']
  def mc_red(str);     MCColor.red(str);     end
  def mc_green(str);   MCColor.green(str);   end
  def mc_yellow(str);  MCColor.yellow(str);  end
else
  def mc_red(str);     str;  end
  def mc_green(str);   str;  end
  def mc_yellow(str);  str;  end
end

module ActiveRecord
  class Migrator

    def check_concordance
      differs = discordant_migrations
      case differs.size
        when 0
          mc_green("***** No changes detected in previously applied migrations.")
        else
          migrated_versions = migrated.collect { |v| v.to_s }
          differs.collect do |version|
            if migrated_versions.include?(version)
              filename = File.basename(Dir["#{@migrations_path}/#{version}_*.rb"].first)
              mc_red("***** Detected change in previously applied migration: #{filename}")
            end
          end
      end
    end

    def discordant_migrations
      schema_entries.collect do |entry|
        migration_hashcode(entry['version']) != entry['hashcode'] ? entry['version'] : nil
      end.compact
    end
    
    def schema_entries
      Base.connection.select_all("SELECT * FROM #{self.class.schema_migrations_table_name}")
    end

    def migration_hashcode(version)
      file = Dir[File.join(@migrations_path, "#{version}_*.rb")].first
      Digest::MD5.hexdigest(File.read(file))
    end

    private

    def record_version_state_after_migrating_with_hashcode(version)
      record_version_state_after_migrating_without_hashcode(version)
      if up?
        ensure_schema_migrations_table_has_extra_columns!
        update_version_hashcode(version)
      end
    end
    alias_method_chain :record_version_state_after_migrating, :hashcode

    def ensure_schema_migrations_table_has_extra_columns!
      sm_table = self.class.schema_migrations_table_name
      existing = Base.connection.columns(self.class.schema_migrations_table_name).collect { |c| c.name }
      Base.connection.add_column(sm_table, 'hashcode', :string)       unless existing.include?('hashcode')
      Base.connection.add_column(sm_table, 'migrated_at', :datetime)  unless existing.include?('migrated_at')
      self.migrated.each { |version| update_version_hashcode(version) }
    end

    def update_version_hashcode(version)
      hashcode = migration_hashcode(version)
      Base.connection.update("UPDATE #{self.class.schema_migrations_table_name} SET hashcode='#{hashcode}',migrated_at='#{Time.now.to_s(:db)}' WHERE version='#{version}'")
    end

  end
end
