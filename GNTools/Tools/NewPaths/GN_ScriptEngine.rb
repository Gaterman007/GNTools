module GNTools
  module NewPaths

    class ScriptEngine

      attr_accessor :global_vars
      attr_reader   :toolpath, :vars, :text

      # -------------------------------------------------
      # Init
      # -------------------------------------------------
      def initialize
        @global_vars = {}
        reset
      end

      def reset
        @toolpath = nil
        @vars     = {}
        @text     = nil
      end

      # -------------------------------------------------
      # Public API
      # -------------------------------------------------
      #
      # run(script_text, toolpath, local_vars = {})
      #  - script_text : String DSL
      #  - toolpath    : Hash
      #  - local_vars  : Hash (override globals)
      #
      def run(script_text, toolpath, local_vars = {})
        reset

        return nil unless script_text
        return nil unless toolpath
		puts "toolpath id #{toolpath}"
        @toolpath = @global_vars["Toolpaths"][toolpath] 
        @vars     = @global_vars.merge(local_vars)
        @text     = script_text.dup
		puts "toolpath #{@global_vars["Toolpaths"][toolpath]}"
		puts "script text #{@text}"
		puts "vars #{@vars}"
        process_foreach!
        process_if!
        process_vars!

        @text
      end

      # -------------------------------------------------
      # FOREACH
      # -------------------------------------------------
      #
      # {foreach p in points}
      #   LINE {p.x} {p.y}
      # {end}
      #
      def process_foreach!
        loop do
          changed = false

          @text.gsub!(
            /\{foreach\s+(\w+)\s+in\s+(\w+)\}(.*?)\{end\}/m
          ) do
            var_name   = Regexp.last_match(1)
            source_key = Regexp.last_match(2)
            block      = Regexp.last_match(3)

            collection = resolve_source(source_key)
            next "" unless collection.is_a?(Array)

            result = collection.map do |item|
              sub = block.dup
              inject_object_vars!(sub, var_name, item)
              sub
            end.join

            changed = true
            result
          end

          break unless changed
        end
      end

      # -------------------------------------------------
      # IF
      # -------------------------------------------------
      #
      # {if depth < 0}
      #   ...
      # {end}
      #
      def process_if!
        loop do
          changed = false

          @text.gsub!(
            /\{if\s+(.+?)\}(.*?)\{end\}/m
          ) do
            condition = Regexp.last_match(1)
            block     = Regexp.last_match(2)

            res = eval_condition(condition) ? block : ""
            changed = true
            res
          end

          break unless changed
        end
      end

      # -------------------------------------------------
      # VARS
      # -------------------------------------------------
      #
      # MOVE {x} {y}
      #
      def process_vars!
        @text.gsub!(/\{([a-zA-Z0-9_\.\[\]]+)\}/) do
          eval_in_schema(Regexp.last_match(1))
        end
      end

      # -------------------------------------------------
      # Evaluation helpers
      # -------------------------------------------------
	  def eval_condition(expr)
	    if expr =~ /(.+?)\s*(==|!=|>=|<=|>|<)\s*(.+)/
		  a = eval_in_schema($1)
		  b = eval_in_schema($3)
		  a = a.to_f rescue a
		  b = b.to_f rescue b

		  case $2
		  when "==" then a == b
		  when "!=" then a != b
		  when ">"  then a >  b
		  when "<"  then a <  b
		  when ">=" then a >= b
		  when "<=" then a <= b
		  end
	    else
		  boolize(eval_in_schema(expr))
	    end
	  rescue
	    false
	  end

	  # -------------------------------------------------
	  # Évaluation des expressions {…} dans le script
	  # -------------------------------------------------
	  def eval_in_schema(expr)
	    puts "expr = #{expr}"
	    expr = expr.strip
	    return "" if expr.empty?

	    # 1 — Literal numérique
	    return expr.to_f if expr.match?(/\A-?\d+(\.\d+)?\z/)

	    # 2 — Vérifier les variables locales / globales
	    if @vars.key?(expr)
		  val = @vars[expr]
		  return format_value(val)
	    end

	    # 3 — Accès aux objets imbriqués via . et tableaux []
	    if expr.include?(".") || expr.include?("[")
		  val = resolve_path(expr)
		  return format_value(val)
	    end

	    # 4 — Si rien trouvé, retourner vide
	    ""
	  end

	  # -------------------------------------------------
	  # Résolution des chemins imbriqués
	  # Exemple :
	  # CurrentTp.points[0].x
	  # Material.metadata.depth.Value
	  # -------------------------------------------------
	  def resolve_path(path)
	    parts = path.split(".")
	    first = parts.shift

	    puts "first = #{first}"
	    puts "parts = #{parts}"

	    # Chercher dans les vars ou toolpath
		# Si c'est CurrentTp, on prend directement @toolpath
	    obj =
		  if first == "CurrentTp"
		    @toolpath
		  else
		    @vars[first]
		  end
	    return "" unless obj

	    parts.each do |part|
		  # Accès tableau : points[0]
		  if part =~ /(\w+)\[(\d+)\]/
		    key = $1
		    idx = $2.to_i
			puts "key = #{key}"
			puts "idx = #{idx}"
		    if obj.is_a?(Hash)
			  obj = obj[key]
		    end
		    if obj.is_a?(Array)
			  obj = obj[idx]
		    else
			  return ""
		    end
		  else
		    # Accès Hash ou objet
		    if obj.is_a?(Hash)
			  obj = obj[part]
		    elsif obj.respond_to?(part)
			  obj = obj.send(part)
		    else
			  return ""
		    end
		  end
		  return "" if obj.nil?
	    end

	    obj
	  end

	  # -------------------------------------------------
	  # Formatage final de la valeur pour le script
	  # -------------------------------------------------
	  def format_value(val)
	    case val
	    when Numeric
		  val.round(4).to_s
	    when Array
		  val.join(",")
	    else
		  val.to_s
	    end
	  end

      def resolve_source(key)
        return @vars[key]     if @vars.key?(key)
        return @toolpath[key] if @toolpath.key?(key)
        []
      end

	  def inject_object_vars!(text, var_name, object)
	    text.gsub!(/\{#{var_name}\.([^\}]+)\}/) do
		  prop = Regexp.last_match(1)
		  if object.is_a?(Hash) && object.key?("pos")
		    case prop
		    when "x" then object["pos"][0]
		    when "y" then object["pos"][1]
		    when "z" then object["pos"][2]
		    else ""
		    end
		  elsif object.respond_to?(prop)
		    object.send(prop)
		  elsif object.is_a?(Hash)
		    object[prop]
		  else
		    ""
		  end
	    end
	  end

      # -------------------------------------------------
      # Utils
      # -------------------------------------------------
      def boolize(v)
        return false if v.nil?
        return v if v == true || v == false
        return v != 0 if v.is_a?(Numeric)
        return v unless v.is_a?(String)

        !(%w[false 0 no off].include?(v.downcase))
      end

    end

  end
end