require 'json'
require 'sketchup'

module GNTools
  module NewPaths

    class GCodeManager
      attr_reader :gcode_data

      # Chargement automatique du fichier JSON
      def initialize
        @json_path = File.join(GNTools::PATH_TOOLS, "GCodeFiles", "GCodes.json")

	    @default_firmware = "Marlin"

        unless File.exist?(@json_path)
          raise "GCodes.json introuvable à : #{@json_path}"
        end

        content = File.read(@json_path)
        @gcode_data = JSON.parse(content)
      end


      # ---------------------------
      #  🔍 Méthodes d’accès
      # ---------------------------

      # Ex: get("G0", "Marlin")
      def get(code, firmware = nil)
        entry = @gcode_data[code]
        return nil unless entry
	    firmware = @default_firmware
        return entry if firmware.nil?
        entry[firmware]
      end

      # Ex: params("G0","GRBL") → ["X","Y","Z","F"]
      def params(code, firmware = nil)
        fw = get(code, firmware)
        fw ? fw["params"] : nil
      end

      # Ex: syntax("G0","Marlin")
      def syntax(code, firmware = nil)
        fw = get(code, firmware)
        fw ? fw["syntax"] : nil
      end

      # Ex: category("G0","Klipper")
      def category(code, firmware = nil)
        fw = get(code, firmware)
        fw ? fw["category"] : nil
      end

      # Ex: exists?("G0")
      def exists?(code)
        @gcode_data.key?(code)
      end

      # Ex: supported_firmwares("G0")
      def supported_firmwares(code)
        entry = @gcode_data[code]
        entry ? entry.keys : []
      end

      # Ex: list_codes → ["G0","G1","G28", ...]
      def list_codes
        @gcode_data.keys
      end

	  # Ex: codes_for_firmware("Marlin") → ["G0","G1", ...]
	  def codes_for_firmware(firmware = nil)
	    firmware ||= @default_firmware

	    @gcode_data.keys.select do |code|
		  entry = @gcode_data[code]
		  entry.key?(firmware)
	    end
	  end

	  # Ex: list_all_firmwares → ["GRBL", "Klipper", "Marlin", "Smoothieware"]
	  def list_all_firmwares
	    @gcode_data.values.flat_map(&:keys).uniq.sort
	  end

      # ---------------------------
      #  🔧 Méthodes futures
      # ---------------------------
      # Tu pourras plus tard ajouter :
      # - validate_params(code, firmware, hash_input)
      # - generate_gcode_line(...)
      # - autocomplete suggestions
      # - help window UI
    end
  end
end