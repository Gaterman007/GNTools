require 'net/http'
require 'uri'
require 'json'
module GNTools
	class OctoPrint
	  def initialize(api_key, host = "http://octopi.local")
		@api_key = api_key
		@host    = host
	  end

	  # --- 1) Uploader un fichier G-code ---
	  def upload(file_path)
		file_name = File.basename(file_path)
		uri = URI.parse("#{@host}/api/files/local")

		boundary = "----SketchupBoundary#{rand(1000000)}"
		post_body = []

		post_body << "--#{boundary}\r\n"
		post_body << "Content-Disposition: form-data; name=\"file\"; filename=\"#{file_name}\"\r\n"
		post_body << "Content-Type: application/octet-stream\r\n\r\n"
		post_body << File.read(file_path)
		post_body << "\r\n--#{boundary}--\r\n"

		request = Net::HTTP::Post.new(uri.request_uri)
		request["X-Api-Key"] = @api_key
		request["Content-Type"] = "multipart/form-data; boundary=#{boundary}"
		request.body = post_body.join

		http = Net::HTTP.new(uri.host, uri.port)
		response = http.request(request)

		puts "Upload: #{response.code} #{response.body}"
		response
	  end

	  # --- 2) Lancer impression d’un fichier déjà présent ---
	  def start_print(file_name)
		uri = URI.parse("#{@host}/api/files/local/#{file_name}")

		request = Net::HTTP::Post.new(uri.request_uri)
		request["X-Api-Key"] = @api_key
		request["Content-Type"] = "application/json"
		request.body = { command: "select", print: true }.to_json

		http = Net::HTTP.new(uri.host, uri.port)
		response = http.request(request)

		puts "Print: #{response.code} #{response.body}"
		response
	  end

	  # --- 3) Envoyer une commande G-code directe ---
	  def send_gcode(cmd)
		uri = URI.parse("#{@host}/api/printer/command")

		request = Net::HTTP::Post.new(uri.request_uri)
		request["X-Api-Key"] = @api_key
		request["Content-Type"] = "application/json"
		request.body = { command: cmd }.to_json

		http = Net::HTTP.new(uri.host, uri.port)
		response = http.request(request)

		puts "G-code: #{response.code} #{response.body}"
		response
	  end

	  # --- 4) Pause impression ---
	  def pause_print
		control_print("pause")
	  end

	  # --- 5) Reprendre impression ---
	  def resume_print
		control_print("resume")
	  end

	  # --- 6) Annuler impression ---
	  def cancel_print
		control_print("cancel")
	  end

	  # --- 7) Obtenir statut impression ---
	  def get_status
		uri = URI.parse("#{@host}/api/job")

		request = Net::HTTP::Get.new(uri.request_uri)
		request["X-Api-Key"] = @api_key

		http = Net::HTTP.new(uri.host, uri.port)
		response = http.request(request)

		if response.code == "200"
		  json = JSON.parse(response.body)
		  puts "Statut: #{json["state"]}, Progression: #{json.dig("progress", "completion")}%"
		  return json
		else
		  puts "Erreur status: #{response.code} #{response.body}"
		  return nil
		end
	  end

	  private

	  def control_print(action)
		uri = URI.parse("#{@host}/api/job")

		request = Net::HTTP::Post.new(uri.request_uri)
		request["X-Api-Key"] = @api_key
		request["Content-Type"] = "application/json"
		request.body = { command: action }.to_json

		http = Net::HTTP.new(uri.host, uri.port)
		response = http.request(request)

		puts "#{action.capitalize}: #{response.code} #{response.body}"
		response
	  end
	end
end