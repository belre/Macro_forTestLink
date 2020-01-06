require 'rexml/document'
require 'rexml/xpath'

# TestSuiteComponent Class
class TestSuiteComponent
	attr :_DEBUG_FLAG 
	
	def initialize
		@_DEBUG_FLAG = 0
	end
	
	def printtext(text)
		if @_DEBUG_FLAG == 1 then
			print text.to_s
		end
	end
	
	# Get node binded by testsuite and retrieve next child node
	def retrieveTestSuite(testsuite_tree, project_xml, testaddr, testlist, depth)
		org_testaddr = testaddr
		
		REXML::XPath.each(project_xml, 'child::node()'){ |node|
			if node.to_s == "\n" then
				next
			end
			
			testaddr = org_testaddr
			
			# In case of Element('Folder' in TestLink)
			if node.kind_of?(REXML::Element) then
				key = node.name
				
				# If specify id, internalid, those include some testcases in testsuites
				if node.attributes['id'] != nil and node.name == 'testsuite' then
					key = key + "_" + node.attributes['id']
					testsuite_tree['testsuite_id'] = node.attributes['id']
					
					testaddr = testaddr + key + '/'
				end
				
				if node.attributes['internalid'] != nil and node.name == 'testcase' then
					key = key + "__" + node.attributes['internalid']
					testsuite_tree['testcase_id'] = node.attributes['internalid']

					testaddr = testaddr + key + '/'
					testlist.push(testaddr)
				end
				
				# Initialize
				if testsuite_tree[key] == nil
					testsuite_tree[key] = {}
				end
				
				# If the parent include blockParameter, copy to child node
				if testsuite_tree['blockParameter'] != nil then
					testsuite_tree[key]['blockParameter'] = []
					testsuite_tree[key]['blockParameter'].push(testsuite_tree['blockParameter'])
				end
				
				# If 'name' of attributes has prefix '__', record those which exclude the prefix '__'
				if node.attributes['name'] != nil and node.attributes['name'].index('__') == 0 then
					if testsuite_tree[key]['blockParameter'] == nil then
						testsuite_tree[key]['blockParameter'] = []
					end

					testsuite_tree[key]['blockParameter'].push(node.attributes['name'][2, node.attributes['name'].length-2])
				end
				
				retrieveTestSuite(testsuite_tree[key], node, testaddr, testlist, depth+1)
				
				
				# Register name as item name
				if node.attributes['name'] != nil then
					testsuite_tree[key]['itemname'] = node.attributes['name']
				end
				
			# In case of CData('TestCase' in TestLink)
			elsif node.kind_of?(REXML::CData) then
				if testsuite_tree['value'] == nil
					testsuite_tree['value'] = []
				end
				testsuite_tree['value'].push(node)
			end
		}
	end
end

# Replace a new line tag to "\n"
def chompHtmlTag(text)
	return text.gsub("<p>","").gsub("</p>","\\n").gsub("<br />", "\\n")
end


testsuite_tree = {}
testlist = []

obj = TestSuiteComponent.new
project_xml = REXML::Document.new(open(ARGV[0]))
obj.retrieveTestSuite(testsuite_tree, project_xml.root, '', testlist, 0)


filepath = ARGV[1]
if filepath == nil then
	filepath = 'log.html'
end

File.open(filepath, 'w') do |fh|
	fh.puts '<meta http-equiv="Content-Type" content="text/html; charset=UTF-8">'
	fh.puts '<html>'
	fh.puts '<body>'
	fh.puts "<table border=1>"
	fh.puts "<tr><th>No</th><th>Document Name</th><th>Request</th><th>Major Category</th><th>Minor Category</th><th>Sub Category</th><th>Test Case</th><th>Action</th><th>Expected Results</th></tr>"
	
	index = 1
	#puts testlist
	(0..testlist.count-1).each do |i|
		allsegs = testlist[i].split('/')

		# Search target
		target = testsuite_tree
		isdetect = true
		details_expr = nil
		(0..allsegs.count-1).each do |j|
			target = target[allsegs[j]]
			if target == nil then
				isdetect = false
			end
			if j == 0 then
				if target['details'] != nil then
					details_expr = target['details']
				end
			end
		end
		
		# Create test case from target
		if isdetect then
			if target['steps'] == nil or  target['steps']['step'] == nil then
				next
			end

			if target['steps']['step']['step_number']['value'] != nil then
				(0..target['steps']['step']['actions']['value'].count-1).each do |j|
					# Index
					fh.puts "<tr><td>"
					fh.puts index.to_s
					fh.puts "</td>"
					
					# Document Name
					fh.puts "<td>"
					if details_expr != nil then
						fh.puts chompHtmlTag(details_expr['value'][0].to_s)
					end
					fh.puts "</td>"
					
					# Request
					fh.puts "<td>"
					if target['summary'] != nil and target['summary']['value'] != nil and target['summary']['value'][0] != nil then
						fh.puts chompHtmlTag(target['summary']['value'][0].to_s)
					end
					fh.puts "</td>"

					# Category
					if target['blockParameter'] != nil then
						val1 = target['blockParameter'][0][1]
						val2 = target['blockParameter'][0][0][1]
						val3 = target['blockParameter'][0][0][0]
						
						if val2 == nil then
							val2 = val1
							val1 = nil
						end
						
						# Major Category
						fh.puts "<td>"
						if val3 != nil then
							fh.puts val3
						end
						fh.puts "</td>"

						# Minor Category
						fh.puts "<td>"				
						if val2 then
							fh.puts val2
						end
						fh.puts "</td>"

						# Sub Category
						fh.puts "<td>"
						if val1 != nil then
							fh.puts val1
						end
						fh.puts "</td>"
					end

					# Test Case
					fh.puts "<td>"				
					fh.puts chompHtmlTag(target['itemname'].to_s)
					fh.puts "</td>"

					# Action
					fh.puts "<td>"				
					fh.puts chompHtmlTag(target['steps']['step']['actions']['value'][j].to_s)
					fh.puts "</td>"
					
					# Expected Results
					fh.puts "<td>"
					fh.puts chompHtmlTag(target['steps']['step']['expectedresults']['value'][j].to_s)
					fh.puts "</td>"
					fh.puts "</tr>"
					
					index = index + 1
				end
			end
		end
	end

	fh.puts "</table>"
	fh.puts "</body></html>"
end

