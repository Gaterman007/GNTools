module GNTools
  module NewPaths

    class BaseScriptEngine

      attr_accessor :global_vars
      attr_reader   :current_tp

      def initialize
        @global_vars = {}
      end

      # -------------------------------------------------
      # API principale
      # -------------------------------------------------
	  def compile(script, current_tp)
	    @current_tp = current_tp
		@vars = @global_vars.merge({"CurrentTp" => @current_tp})
	    lines = script.lines
	    compile_block(lines)
	  end

      # -------------------------------------------------
      # Scope initial
      # -------------------------------------------------
      def base_scope
        {
          "CurrentTp" => @current_tp,
          "Material"  => @global_vars["Material"]
        }
      end

      # -------------------------------------------------
      # Compilation bloc
      # -------------------------------------------------
	  def compile_block(lines)
		instructions = []
		i = 0
		while i < lines.size
		  line = lines[i].strip
		  i += 1
		  next if line.empty?
		  checkline = line.sub(/[;#].*$/, '').strip
		  if checkline =~ /\{foreach\s+(\w+)\s+in\s+(.+?)\}/
			var_name = $1
			source_expr = $2
			block, i = extract_block_from(lines, i)
			compile_foreach(var_name, source_expr, block)
		  elsif checkline =~ /\{if\s+(.+?)\}/
			condition = $1
			block, i = extract_block_from(lines, i)
			compile_if(condition, block)
		  else
			handle_instruction(line)   # <-- au lieu de instructions << ...
		  end
		end
	  end

	  # Méthode par défaut
	  def handle_instruction(inst)
		# juste retourner l'Instruction par défaut si besoin
		inst
	  end

	  def compile_foreach(var_name, source_expr, block_lines)
	    collection = eval_expr(source_expr)
	    return [] unless collection.is_a?(Array)

	    collection.flat_map do |item|
		  with_var(var_name, item) do
		    compile_block(block_lines)
		  end
	    end
	  end

	  def compile_if(condition, block_lines)
	    return [] unless eval_condition(condition)
	    compile_block(block_lines)
	  end

      def eval_token(token)
        if token =~ /\{(.+?)\}/
          eval_expr($1)
        else
          token.to_f rescue token
        end
      end

      def eval_expr(expr)
        parts = expr.split(".")
        obj = @vars[parts.shift]

        parts.each do |p|
          if p =~ /(\w+)\[(\-?\d+)\]/
            obj = obj[$1][$2.to_i]
          elsif obj.is_a?(Hash)
            obj = obj[p]
          else
            obj = obj.send(p)
          end
        end

        obj
      rescue
        nil
      end

      def with_var(name, value)
        old = @vars[name]
        @vars[name] = value
        res = yield
        @vars[name] = old
        res
      end

      def extract_block(text)
        text[/\{.*?\}(.*?)\{end\}/m, 1]
      end
	  
	  def extract_block_from(lines, start_index)
	    depth = 1
	    block = []

	    i = start_index
	    while i < lines.size
		  line = lines[i]

		  depth += 1 if line =~ /\{(foreach|if)\b/
		  depth -= 1 if line =~ /\{end\}/

		  break if depth == 0

		  block << line
		  i += 1
	    end

	    [block, i + 1]
	  end
	end

  end
end