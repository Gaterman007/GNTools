require 'net/http'
require 'uri'
require 'json'
module GNTools
	class OctoPrint
	#octo = GNTools::OctoPrint.new("w3hB9JoyaOEj07EWqCLUbpjrsPtbYXp7cbkw8MqT_x4")
	  def initialize(api_key, host = "http://10.0.0.108:5000")
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

	  # --- Télécharger un fichier G-code depuis OctoPrint ---
	  def download(file_name, save_path)
	    uri = URI.parse("#{@host}/downloads/files/local/#{file_name}")

	    request = Net::HTTP::Get.new(uri.request_uri)
	    request["X-Api-Key"] = @api_key

	    http = Net::HTTP.new(uri.host, uri.port)
	    response = http.request(request)

	    if response.code == "200"
	      File.open(save_path, "wb") { |f| f.write(response.body) }
		  puts "Fichier téléchargé : #{save_path}"
		  return true
	    else
		  puts "Erreur download: #{response.code} #{response.body}"
		  return false
	    end
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

	  # --- Uploader une chaîne comme fichier G-code ---
	  def upload_string(content, file_name = "virtual.gcode")
	    uri = URI.parse("#{@host}/api/files/local")

	    boundary = "----SketchupBoundary#{rand(1000000)}"
	    post_body = []

	    post_body << "--#{boundary}\r\n"
	    post_body << "Content-Disposition: form-data; name=\"file\"; filename=\"#{file_name}\"\r\n"
	    post_body << "Content-Type: application/octet-stream\r\n\r\n"
	    post_body << content
	    post_body << "\r\n--#{boundary}--\r\n"

	    request = Net::HTTP::Post.new(uri.request_uri)
	    request["X-Api-Key"] = @api_key
	    request["Content-Type"] = "multipart/form-data; boundary=#{boundary}"
	    request.body = post_body.join

	    http = Net::HTTP.new(uri.host, uri.port)
	    response = http.request(request)

	    puts "Upload string: #{response.code} #{response.body}"
	    response
	  end
  
	  # --- Télécharger un fichier G-code et retourner son contenu comme string ---
	  def download_string(file_name)
	    uri = URI.parse("#{@host}/downloads/files/local/#{file_name}")

	    request = Net::HTTP::Get.new(uri.request_uri)
	    request["X-Api-Key"] = @api_key

	    http = Net::HTTP.new(uri.host, uri.port)
	    response = http.request(request)

	    if response.code == "200"
	      puts "Download string OK (#{file_name}, taille: #{response.body.size} octets)"
		  return response.body   # contenu texte du G-code
	    else
		  puts "Erreur download string: #{response.code} #{response.body}"
		  return nil
	    end
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
	  
      # --- 8) Vérifier le statut global de l'imprimante ---
      def printer_status
	    uri = URI.parse("#{@host}/api/printer")

	    request = Net::HTTP::Get.new(uri.request_uri)
	    request["X-Api-Key"] = @api_key

	    http = Net::HTTP.new(uri.host, uri.port)
	    response = http.request(request)

	    if response.code == "200"
		  json = JSON.parse(response.body)
		  # Exemple d'information utile
		  state = json.dig("state", "text")
		  temperature = json["temperature"]
		  puts "Printer Status: #{state}"
		  puts "Temperatures: #{temperature}"
		  return json
	    else
		  puts "Erreur printer_status: #{response.code} #{response.body}"
		  return nil
	    end
	  end
    end  # class OctoPrint
end # method GNTools