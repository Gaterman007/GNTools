module GNTools

	def self.checkEpsilon(epsi)
		if epsi < Float::EPSILON && epsi > -Float::EPSILON
			epsi = 0
		end
		epsi
	end
	
	class LoopSegments
	
		attr_accessor :segmentTbl
		attr_accessor :boundbox
		attr_accessor :linearray
		
		def initialize()
			@segmentTbl = []
			@boundbox = Geom::BoundingBox.new
			@linearray = []

		end
		
		def count
			@segmentTbl.count
		end
		
		def add_Seg(param)
			if param.class == Sketchup::Edge
				segmentTbl.push(Segment3d.new(param.start.position,param.end.position))
			elsif param.class == GNTools::Segment3d
				segmentTbl.push(Segment3d.new(param.startpos,param.endpos))
			else
				return false
			end
			return true
		end
		
		def classArray(params)
			p "array"
			params.each { |paramSel|
				self.add_Seg(paramSel)
			}
		end
		
		def classSelection(params)
#			p "selection"
			params.each { |paramSel|
				self.add_Segments(paramSel)
			}
		
		end
		
		def classGroup(params)
			params.entities.each { |paramSel|
				self.add_Segments(paramSel)
			}
		end
		
		def add_Segments(*args)
			if args.count > 0
				args.each { |params|
					if !add_Seg(params)
#						p params.class
						if params.class == Array
							classArray(params)
						elsif params.class == Sketchup::Edge
							segmentTbl.push(Segment3d.new(params.start.position,params.end.position))
						elsif params.class == GNTools::Segment3d
							segmentTbl.push(Segment3d.new(params.startpos,params.endpos))
						elsif params.class == Sketchup::Selection
							classSelection(params)
						elsif params.class == Sketchup::Face
							nil
						elsif params.class == Sketchup::Group
							classGroup(params)
						else
							p "not defined"
						end
					end
				}
			end
			nil
		end

		def clear()
			@segmentTbl = []
			@linearray = []
			@boundbox.clear()
		end

		def add_Segment(startpos = Geom::Point3d.new(0,0,0),endpos = Geom::Point3d.new(0,0,0))
			segmentTbl.push(Segment3d.new(startpos,endpos))
		end
		
		def reverseLoop
			reverseSegmentTbl = self.segmentTbl 
			reverseSegmentTbl.each { |segment|
				startpos = segment.endpos
				endpos = segment.startpos
				segment.endpos = endpos
				segment.startpos = startpos
			}		
		end
		
		def sortedges()
			# sort faceedges start end 
			newsegmentTbl = []
			oldsegmentTbl = []
			segmentTbl.each { |segment|
				oldsegmentTbl.push(Segment3d.new(segment.startpos,segment.endpos))
			}
			edgetofind = segmentTbl[0]
			newsegmentTbl.push(GNTools::Segment3d.new(edgetofind.startpos,edgetofind.endpos))
			segmentTbl.slice!(0) 
			positiontofind = edgetofind.endpos
			closedLoop = true
			while (segmentTbl.count > 0 && closedLoop)
				edgefound = segmentTbl.find {|i| i.startpos == positiontofind}
				if edgefound
				  edgetofind = edgefound
				  newsegmentTbl.push(GNTools::Segment3d.new(Geom::Point3d.new(edgetofind.startpos),Geom::Point3d.new(edgetofind.endpos)))
				  segmentTbl.delete_at(segmentTbl.index(edgetofind))
				  positiontofind = edgetofind.endpos
				else
				  edgefound = segmentTbl.find {|i| i.endpos == positiontofind}
				  if edgefound
					  edgetofind = edgefound
					  newsegmentTbl.push(GNTools::Segment3d.new(Geom::Point3d.new(edgetofind.endpos),Geom::Point3d.new(edgetofind.startpos)))
					  segmentTbl.delete_at(segmentTbl.index(edgetofind))
					  positiontofind = edgetofind.startpos
				  else
					closedLoop = false
					while (segmentTbl.count > 0)
						newsegmentTbl.push(segmentTbl[0])
						segmentTbl.shift()
					end
				  end
				end
			end
			segmentTbl = []
			oldsegmentTbl.each { |segment|
				segmentTbl.push(segment)
			}
			[newsegmentTbl,closedLoop]
		end
		
		def sortedges!
			# sort faceedges start end 
			newsegmentTbl = []
			edgetofind = segmentTbl[0]
			newsegmentTbl.push(GNTools::Segment3d.new(edgetofind.startpos,edgetofind.endpos))
			segmentTbl.slice!(0) 
			positiontofind = edgetofind.endpos
			closedLoop = true
			while (segmentTbl.count > 0 && closedLoop)
				edgefound = segmentTbl.find {|i| i.startpos == positiontofind}
				if edgefound
				  edgetofind = edgefound
				  newsegmentTbl.push(GNTools::Segment3d.new(Geom::Point3d.new(edgetofind.startpos),Geom::Point3d.new(edgetofind.endpos)))
				  segmentTbl.delete_at(segmentTbl.index(edgetofind))
				  positiontofind = edgetofind.endpos
				else
				  edgefound = segmentTbl.find {|i| i.endpos == positiontofind}
				  if edgefound
					  edgetofind = edgefound
					  newsegmentTbl.push(GNTools::Segment3d.new(Geom::Point3d.new(edgetofind.endpos),Geom::Point3d.new(edgetofind.startpos)))
					  segmentTbl.delete_at(segmentTbl.index(edgetofind))
					  positiontofind = edgetofind.startpos
				  else
					closedLoop = false
					while (segmentTbl.count > 0)
						newsegmentTbl.push(segmentTbl[0])
						segmentTbl.shift()
					end
				  end
				end
			end
			newsegmentTbl.each { |segment|
				segmentTbl.push(segment)
			}
			closedLoop
		end
		
		def setBondingBox()
			@boundbox.clear
			@segmentTbl.each { |segment|
				@boundbox.add(segment.startpos)
				@boundbox.add(segment.endpos)
			}
			@boundbox
		end
		
		def linesFaces(offset)
		  self.sortedges!
		  self.setBondingBox
		  seg1 = GNTools::Segment3d.new()
		  seg1.startpos = @boundbox.min.clone
		  seg1.endpos = @boundbox.max.clone
		  seg1.endpos.x = seg1.startpos.x
		  @linearray = []
		  (@boundbox.min.x + offset ... @boundbox.max.x - offset).step(offset) { |index|
			seg1.startpos.x = index
			seg1.endpos.x = index
			parray = []
			nbDeSegment = 0
			segmentTbl.each { |entity|
				array =  GNTools::Segment3d.LineLineIntersect(seg1,entity)
				if array.count > 0
				  if entity.isOnSegment(array[0].startpos)
					nbDeSegment = nbDeSegment + 1
					if array[0].startpos == entity.startpos 
					  parray.push(array[0].startpos)
					else
						if array[0].startpos == entity.endpos 
						  parray.push(array[0].startpos)
						else
						  parray.push(array[0].startpos)
						end
					end
				  end
				end
			}
			if parray.count > 0  
			  if parray.count > 2
				parray.sort! { |a,b| Geom::Vector3d.new(a - parray[0]).length <=> Geom::Vector3d.new(b - parray[0]).length}
				(0 ... parray.count).step(2) { |index|
				  @linearray.push([GNTools::Segment3d.new(parray[index],parray[index+1])])
				}
			  else
				@linearray.push([GNTools::Segment3d.new(parray[0],parray[1])])
			  end
			end
		  }
		  @linearray
		end
		
		def createCline(entities,offset)
			linesFaces(offset)
			@linearray.each { |cline|
				cline[0].createCline(entities)
			}
		end
		
		def createVectorTbl
			vectorTbl = []
			(0 ... @segmentTbl.count).step(1) { |index|
				vectorTbl.push(Geom::Vector3d.new(@segmentTbl[index].endpos - @segmentTbl[index].startpos))
			}
			vectorTbl
		end

		def signdotvector(v1,normalvectorperpenticulaire,sign,convex)
			normalvectorperpenticulairedot = normalvectorperpenticulaire.dot(v1)
			normalvectorperpenticulairedot = GNTools::checkEpsilon(normalvectorperpenticulairedot)
			if normalvectorperpenticulairedot > 0
				if sign == -1
				  convex = false
				elsif sign == 0
				  sign = 1
				end
			elsif normalvectorperpenticulairedot < 0
				if sign == 1
				  convex = false
				elsif sign == 0
 				  sign = -1
				end
			end
			[sign,convex]
		end
		
		def loopConvex
			self.sortedges!
			self.setBondingBox
			vectorTbl = createVectorTbl
			planenormal = Geom::Vector3d.new(vectorTbl[0] * vectorTbl[1])
			planenormal.normalize!
			convex = true
# pour chaque vector 
			sign = 0
			(0 ... vectorTbl.count).step(1) { |indexvector|
			  vectortest = vectorTbl[indexvector]
			  testvecstart = @segmentTbl[indexvector].startpos
			  normalvectorperpenticulaire = vectortest.cross(planenormal) 
			  v1 = Geom::Vector3d.new(testvecstart - @segmentTbl[2].startpos)
			  signarray = signdotvector(v1,normalvectorperpenticulaire,sign,convex)
			  sign = signarray[0]
			  convex = signarray[1]
#verifier avec chaquepoint si tout meme coté
			  (0 ... @segmentTbl.count).step(1) { |index|
				  segment1 = @segmentTbl[index]
				  endpos = segment1.endpos
				  startpos = segment1.startpos
				  v1 = Geom::Vector3d.new(testvecstart - startpos)
				  signarray = signdotvector(v1,normalvectorperpenticulaire,sign,convex)
				  sign = signarray[0]
				  convex = signarray[1]
			  }
			}
			convex
		end
		
		def ligneParalelle(offset)
		  newlines = []
		  self.sortedges!
		  self.setBondingBox
		  v1 = Geom::Vector3d.new(self.segmentTbl[0].endpos - self.segmentTbl[0].startpos)
		  v2 = Geom::Vector3d.new(self.segmentTbl[1].startpos - self.segmentTbl[1].endpos)
		  normal = Geom::Vector3d.new(v1 * v2)
		  normal.normalize!
		  (0 ... self.segmentTbl.count).step(1) { |index|
			  segment1 = self.segmentTbl[index]
			  endpos = segment1.endpos
			  startpos = segment1.startpos
			  v1 = Geom::Vector3d.new(endpos - startpos)
			  perpendiculaire = v1.cross(normal)
			  perpendiculaire.normalize!
			  v2 = Geom::Vector3d.new( perpendiculaire.x.mm * offset, perpendiculaire.y.mm * offset, perpendiculaire.z.mm  * offset)
			  newlines.push(GNTools::Segment3d.new(endpos + v2,startpos + v2))
		  }
		  newlines
		end
		
		def offsetFace(offset)
		  newlines = ligneParalelle(offset)
		  (0 ... newlines.count).step(1) { |index|
			  segment1 = newlines[index - 1]
			  segment2 = newlines[index]
			  ar = GNTools::Segment3d.LineLineIntersect(segment1,segment2)
			  newlines[index - 1].endpos = ar[0].startpos
			  newlines[index].startpos = ar[0].startpos
		  }
		  newlines
		end

		def midpoint(seg1,seg2)
			#segment to vector
			v1 = seg1.toVector(true)
			v2 = seg2.toVector(false)
			n1 = v1.normalize
			n2 = v2.normalize
			n3 = n1+n2
			n3.normalize
		end
		
		def angle_between(seg1,seg2)
			#segment to vector
			v1 = seg1.toVector(true)
			v2 = seg2.toVector(false)
			n1 = v1.normalize
			n2 = v2.normalize

			ratio = n1.x * n2.x + n1.y * n2.y + n1.z * n2.z


			if ratio < 0.0
			  x = -n1.x - n2.x
			  y = -n1.y - n2.y
			  z = -n1.z - n2.z
			  length = Math.sqrt(x * x + y * y + z * z)
			  theta = Math::PI - 2.0 * Math.asin(length / 2.0)
			else
			  x = n1.x - n2.x
			  y = n1.y - n2.y
			  z = n1.z - n2.z
			  length = Math.sqrt(x * x + y * y + z * z)
			  theta = 2.0 * Math.asin(length / 2.0)
			end

			# Convert from radians to degrees
			angle = theta * (180.0 / Math::PI)
			angle
		end

		def draw(view)
			@segmentTbl.each { |segment|
				segment.draw(view)
			}
		end
	end
	
	class Line3d
		attr_accessor :direction
		attr_accessor :point

		def initialize(direction = Geom::Vector3d.new(0,0,0),point = Geom::Point3d.new(0,0,0))
			@direction = direction
			@point = point
		end
		
	end
	
	class Plan3d
		attr_accessor :normal
		attr_accessor :d

		def initialize(normal = Geom::Vector3d.new(0,0,0),d = Geom::Point3d.new(0,0,0))
			@normal = normal
			@d = d
		end
	end
	
	class Segment3d
		attr_accessor :startpos
		attr_accessor :endpos

		def initialize(startpos = Geom::Point3d.new(0,0,0),endpos = Geom::Point3d.new(0,0,0))
			@startpos = startpos
			@endpos = endpos
		end
		
		def cross(segment)
			p13 = Geom::Vector3d.new(segment.endpos - segment.startpos)
			p23 = Geom::Vector3d.new(startpos - endpos)
			returnValue = Geom::Vector3d.new()
			returnValue.x = p13.y * p23.z - p13.z * p23.y
			returnValue.y = p13.z * p23.x - p13.x * p23.z
			returnValue.z = p13.x * p23.y - p13.y * p23.x
			returnValue
		end

		def toVector(inv = true)
			if inv
				v1 = Geom::Vector3d.new(endpos - startpos)
			else
				v1 = Geom::Vector3d.new(startpos - endpos)
			end
			v1
		end
		
		def getLine
			direction = Geom::Vector3d.new(startpos - endpos)
			point = startpos
			[direction,point]
		end
		
		def self.LineLineIntersect(p1p2,p3p4)
			p13 = Geom::Vector3d.new(p1p2.startpos - p3p4.startpos)
			p43 = Geom::Vector3d.new(p3p4.startpos - p3p4.endpos)
			# segment start and end is same
			if ((p43.x).abs < Float::EPSILON && (p43.y).abs < Float::EPSILON && (p43.z).abs < Float::EPSILON)
				return []
			end
			p21 = Geom::Vector3d.new(p1p2.endpos - p1p2.startpos)
			# segment start and end is same
			if ((p21.x).abs < Float::EPSILON && (p21.y).abs < Float::EPSILON && (p21.z).abs < Float::EPSILON)
				return []
			end
			d1343 = p13.dot(p43)
			d4321 = p43.dot(p21)
			d1321 = p13.dot(p21)
			d4343 = p43.dot(p43)
			d2121 = p21.dot(p21)
			
			denom = d2121 * d4343 - d4321 * d4321;
			if ((denom).abs < Float::EPSILON)
				return []
			end
			numer = d1343 * d4321 - d1321 * d4343;

			mua = numer / denom;
			mub = (d1343 + d4321 * (mua)) / d4343;

			papb = Segment3d.new()
			
			
			xpos = p1p2.startpos.x + mua * p21.x
			ypos = p1p2.startpos.y + mua * p21.y;
			zpos = p1p2.startpos.z + mua * p21.z;
			
			papb.startpos.x = xpos
			papb.startpos.y = ypos;
			papb.startpos.z = zpos;
#			minEpsilon =  1.0e-07
			if xpos < Float::EPSILON && xpos > -Float::EPSILON
			   papb.startpos.x = 0
			end
			if ypos < Float::EPSILON && ypos > -Float::EPSILON
			   papb.startpos.y = 0
			end
			if zpos < Float::EPSILON && zpos > -Float::EPSILON
			   papb.startpos.z = 0
			end
			
			xpos = p3p4.startpos.x + mub * p43.x;
			ypos = p3p4.startpos.y + mub * p43.y;
			zpos = p3p4.startpos.z + mub * p43.z;

			papb.endpos.x = xpos;
			papb.endpos.y = ypos;
			papb.endpos.z = zpos;

			if xpos < Float::EPSILON && xpos > -Float::EPSILON
			   papb.endpos.x = 0
			end
			if ypos < Float::EPSILON && ypos > -Float::EPSILON
			   papb.endpos.y = 0
			end
			if zpos < Float::EPSILON && zpos > -Float::EPSILON
			   papb.endpos.z = 0
			end
			return [papb,mua,mub]
		end
		
		def isOnSegment(point)
			vline = Geom::Vector3d.new(@endpos - @startpos)
#			p "length"
			vpoint1 = Geom::Vector3d.new(point - @startpos)
			vpoint2 = Geom::Vector3d.new(point - @endpos)
			length = vline.length
			length2 = vpoint1.length
			length3 = vpoint2.length
#			p length
#			p length2
			if length2.to_f > length.to_f || length3.to_f > length.to_f
				return false
			end
			vline.normalize!
			return true
		end

		def onSide(point)
		  v1 = Geom::Vector3d.new(point - @startpos)
		  v2 = Geom::Vector3d.new(@endpos - @startpos)
		  planenormal = Geom::Vector3d.new(v1 * v2)
		  planenormal.normalize!
		end


		def draw(view)
				view.set_color_from_line(@startpos,@endpos)
				view.line_width = 1
#view.line_stipple = '-'
#"." (Dotted Line),
#"-" (Short Dashes Line),
#"_" (Long Dashes Line),
#"-.-" (Dash Dot Dash Line),
#"" (Solid Line).#
#view.line_stipple = '_'      
				view.line_stipple = ''      
				view.draw(GL_LINES, @startpos,@endpos)
		end

		def createCline(entities)
			entities.add_cline(@startpos,@endpos)
		end

		def createInfiniteCline(entities)
			entities.add_cline(@startpos,@endpos - @startpos)
		end
		
		def ==(other)
			self.startpos  == other.startpos &&
			self.endpos == other.endpos
		end

		def inspect
#			"id: #{object_id} startpos: #{@startpos} endpos: #{@endpos}"
			"startpos: #{@startpos} endpos: #{@endpos}"
		end
		
		def to_s
			"startpos: #{@startpos} endpos: #{@endpos}"
		end
	end

	class Rayon3d
		attr_accessor :direction
		attr_accessor :point
		
		def initialize()
			point = Geom::Vector3d.new(0,0,0)
			direction = Geom::Vector3d.new(0,0,1)
		end
		
		def initForm2Point(p1,p2)
			v2 = Geom::Vector3d.new(p2)
			v1 = Geom::Vector3d.new(p1)
			direction = v2-v1
			point = p1
		end
				
	end
end  # namespace GNTools