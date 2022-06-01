require "json"
require "semantic_version"

require "./error"

# Adds JSON serialisation
require "../ext/semantic_version"

module PlaceOS::Model
  # Information pertaining to a driver binary
  #
  class Executable
    include JSON::Serializable

    # `entrypoint` is the entrypoint to the file relative to its `shard.yml`
    getter entrypoint : String

    getter commit : String

    getter digest : String

    getter crystal_version : SemanticVersion

    def_equals_and_hash entrypoint, commit, digest, crystal_version

    private SEPERATOR = '-'

    def initialize(@entrypoint, @commit, @digest, crystal_version)
      crystal_version = crystal_version.value if crystal_version.is_a? Shards::Version
      @commit = self.class.normalized_commit(@commit)
      @crystal_version = SemanticVersion.parse(crystal_version)
    end

    def initialize(filename : String)
      begin
        name, commit, digest, crystal_version, encoded_directory = File.basename(filename).split(SEPERATOR)
        directory = Base64.decode_string(encoded_directory)
        crystal_version = SemanticVersion.parse(crystal_version)
      rescue e
        raise Error.new("#{File.basename(filename)} is not well-formed", cause: e)
      end

      @entrypoint = File.join(directory, "#{name}.cr")
      @commit = self.class.normalized_commit(commit)
      @digest = digest
      @crystal_version = crystal_version
    end

    @[JSON::Field(ignore: true)]
    getter name : String do
      self.class.name(entrypoint)
    end

    @[JSON::Field(ignore: true)]
    getter encoded_directory : String do
      self.class.encoded_directory(entrypoint)
    end

    @[JSON::Field(ignore: true)]
    getter filename : String do
      {name, commit, digest, crystal_version, encoded_directory}.join(SEPERATOR)
    end

    def to_s(io)
      io << "Driver(" << entrypoint << '@' << commit
      io << ", digest=" << digest
      io << ", crystal=" << crystal_version
      io << ")"
    end

    INFO_EXT = ".info"

    @[JSON::Field(ignore: true)]
    getter info_filename : String do
      "#{filename}#{INFO_EXT}"
    end

    def self.name(entrypoint)
      Path[entrypoint].basename.rchop(".cr")
    end

    # The default short commit hash is 7 characters
    def self.normalized_commit(commit : String)
      commit[0, 7]
    end

    def self.encoded_directory(entrypoint)
      Base64.urlsafe_encode(Path[entrypoint].dirname, padding: false)
    end

    # Produces a glob to match relevant executables
    #
    def self.glob(entrypoint : String?, commit : String?, digest : String?, crystal_version : SemanticVersion | String?)
      {
        entrypoint.try &->name(String),
        commit.try &->normalized_commit(String),
        digest,
        crystal_version,
        entrypoint.try &->encoded_directory(String),
      }.join(SEPERATOR) do |value|
        value || "*"
      end
    end

    record Info, defaults : String, metadata : String, documentation : String = "" do
      include JSON::Serializable
    end

    private record Defaults, output : String
    private record Metadata, output : String

    protected def info(binary_store_path : String) : Info
      path = File.join(binary_store_path, filename)
      raise Error.new("Expected driver at #{path}") unless File.exists?(path)

      result_channel = Channel(Defaults | Metadata | Error).new(2)

      spawn do
        result = run_driver(path, {"--defaults"})
        result_channel.send result.is_a?(String) ? Defaults.new(result) : result
      end

      spawn do
        result = run_driver(path, {"--metadata"})
        result_channel.send result.is_a?(String) ? Metadata.new(result) : result
      end

      metadata = nil
      defaults = nil
      error = nil

      2.times do
        case (result = result_channel.receive)
        in Defaults then defaults = result.output
        in Metadata then metadata = result.output
        in Error    then error = result
        end
      end

      raise error unless error.nil?
      raise Error.new("Unexpected driver output") if metadata.nil? || defaults.nil?

      Info.new(defaults, metadata)
    end

    private def run_driver(path, args) : String | Error
      output = IO::Memory.new
      Process.run(path, args, output: output, error: output).success? ? output.to_s : Error.new output.to_s
    end
  end
end
