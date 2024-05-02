# frozen_string_literal: true

module SplitIoClient
  class Semver
    METADATA_DELIMITER = '+'
    PRE_RELEASE_DELIMITER = '-'
    VALUE_DELIMITER = '.'

    attr_reader :major, :minor, :patch, :pre_release, :is_stable, :version

    def initialize(version)
      @major = 0
      @minor = 0
      @patch = 0
      @pre_release = []
      @is_stable = false
      @version = ''
      @metadata = ''
      parse(version)
    end

    #
    # Class builder
    #
    # @param version [String] raw version as read from splitChanges response.
    #
    # @return [type] Semver instance
    def self.build(version, logger)
      new(version)
    rescue NoMethodError => e
      logger.error("Failed to parse Semver data, incorrect data type:  #{e}")
      nil
    rescue StandardError => e
      logger.error("Failed to parse Semver data:  #{e}")
      nil
    end

    #
    # Check if there is any metadata characters in version.
    #
    # @return [type] String semver without the metadata
    #
    def remove_metadata_if_exists(old_version)
      index = old_version.index(METADATA_DELIMITER)
      return old_version if index.nil?

      @metadata = old_version[index + 1, old_version.length]
      old_version[0, index]
    end

    # Compare the current Semver object to a given Semver object, return:
    #      0: if self == passed
    #      1: if self > passed
    #      -1: if self < passed
    #
    # @param to_compare [trype] splitio.models.grammar.matchers.semver.Semver object
    #
    # @returns [Integer] based on comparison
    def compare(to_compare)
      return 0 if @version == to_compare.version

      # Compare major, minor, and patch versions numerically
      result = compare_attributes(to_compare)
      return result if result != 0

      # Compare pre-release versions lexically
      compare_pre_release(to_compare)
    end

    private

    def integer?(value)
      value.to_i.to_s == value
    end

    #
    # Parse the string in version to update the other internal variables
    #
    def parse(old_version)
      without_metadata = remove_metadata_if_exists(old_version)

      index = without_metadata.index(PRE_RELEASE_DELIMITER)
      if index.nil?
        @is_stable = true
      else
        pre_release_data = without_metadata[index + 1..-1]
        without_metadata = without_metadata[0, index]
        @pre_release = pre_release_data.split(VALUE_DELIMITER)
      end
      assign_major_minor_and_patch(without_metadata)
    end

    #
    # Set the major, minor and patch internal variables based on string passed.
    #
    # @param version [String] raw version containing major.minor.patch numbers.
    def assign_major_minor_and_patch(version)
      parts = version.split(VALUE_DELIMITER)
      if parts.length != 3 ||
         !(integer?(parts[0]) &&
           integer?(parts[1]) &&
           integer?(parts[2]))
        raise "Unable to convert to Semver, incorrect format: #{version}"
      end

      @major = parts[0].to_i
      @minor = parts[1].to_i
      @patch = parts[2].to_i
      @version = "#{@major}#{VALUE_DELIMITER}#{@minor}#{VALUE_DELIMITER}#{@patch}"
      @version += "#{PRE_RELEASE_DELIMITER}#{@pre_release.join('.')}" unless @pre_release.empty?
      @version += "#{METADATA_DELIMITER}#{@metadata}" unless @metadata.empty?
    end

    #
    # Compare 2 variables and return int as follows:
    #    0: if var1 == var2
    #    1: if var1 > var2
    #    -1: if var1 < var2
    #
    # @param var1 [type] String/Integer object that accept ==, < or > operators
    # @param var2 [type] String/Integer object that accept ==, < or > operators
    #
    # @returns [Integer] based on comparison
    def compare_vars(var1, var2)
      return 0 if var1 == var2

      return 1 if var1 > var2

      -1
    end

    # Compare the current Semver object's major, minor, patch and is_stable attributes to a given Semver object, return:
    #      0: if self == passed
    #      1: if self > passed
    #      -1: if self < passed
    #
    # @param to_compare [trype] splitio.models.grammar.matchers.semver.Semver object
    #
    # @returns [Integer] based on comparison
    def compare_attributes(to_compare)
      result = compare_vars(@major, to_compare.major)
      return result if result != 0

      result = compare_vars(@minor, to_compare.minor)
      return result if result != 0

      result = compare_vars(@patch, to_compare.patch)
      return result if result != 0

      return -1 if !@is_stable && to_compare.is_stable

      return 1 if @is_stable && !to_compare.is_stable

      0
    end

    # Compare the current Semver object's pre_release attribute to a given Semver object, return:
    #      0: if self == passed
    #      1: if self > passed
    #      -1: if self < passed
    #
    # @param to_compare [trype] splitio.models.grammar.matchers.semver.Semver object
    #
    # @returns [Integer] based on comparison
    def compare_pre_release(to_compare)
      min_length = get_pre_min_length(to_compare)
      0.upto(min_length - 1) do |i|
        next if @pre_release[i] == to_compare.pre_release[i]

        if integer?(@pre_release[i]) && integer?(to_compare.pre_release[i])
          return compare_vars(@pre_release[i].to_i, to_compare.pre_release[i].to_i)
        end

        return compare_vars(@pre_release[i], to_compare.pre_release[i])
      end
      # Compare lengths of pre-release versions
      compare_vars(@pre_release.length, to_compare.pre_release.length)
    end

    # Get minimum of current Semver object's pre_release attributes length to a given Semver object
    #
    # @param to_compare [trype] splitio.models.grammar.matchers.semver.Semver object
    #
    # @returns [Integer]
    def get_pre_min_length(to_compare)
      [@pre_release.length, to_compare.pre_release.length].min
    end
  end
end
