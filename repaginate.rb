# Repaginate -- stitch OCR'd pages together into documents
# An algorithm based on detecting "types" of pages, such as different types of start and end pages
# Currently tailored to the iraq contracter FOIA data set, but the technique is general
# Outputs as CSV, one doc per row. 
# If optional URL argument provided, second column of CSV is URL to embeded viewer (URLs formatted for DocumentCloud)

require 'amatch'
require 'CSV'
require 'Set'
require 'Digest'
include Amatch


# ------------------ Approximate matcher -- does this document match the "first page" template? -------------- 

# Matches a document if it contains K out of N lines, each approximately matched 
class KofNLineMatcher
  
  # Takes hash of N { line, threshold } pairs, and K=number of lines which must (fuzzy) match
  def initialize(lines, k)
    @linematchers = {}
    @k = k
    lines.each do |line, thresh|
      stripped = line.upcase.gsub(/\s+/,"");     # ignore spaces in match, this handles of accidental double-spacing that ABBY sometimes applies
      matcher = Levenshtein.new(stripped)
      @linematchers[matcher] = thresh
    end
  end

  # takes array of lines, returns the K mangled strings that matched, or null if doc does not match
  def match?(textlines)
    matches = {}
    matchcount = 0
    
    # check each line against each string
    textlines.each do |line|  
      
      # strip all chars that aren't alphanumeric, incl spaces -- this helps hugely with OCR junk
      stripped = line.upcase.gsub(/[^A-Z]/,"")
      
      # try to match this line against each string. store the original (unstripped) line if match
      @linematchers.each do |matcher, thresh|
        if !matches.has_key?(matcher)
          if matcher.match(stripped) < thresh
            matches[matcher] = line
            matchcount+= 1
            if matchcount == @k
              #break #comment this break if you want to return all lines matched, not just the first k
            end
          end
        end
      end      
    end
    
    # assemble matched lines together and return, if we matched at least k. useful for debugging!
    # otherwise return nil
    if (matchcount >= @k)
      matchedlines = " -- "
      matches.each do |matcher, line|
        matchedlines += line.to_s.strip + " -- "
      end
      return matchedlines
    else
      return nil
    end
  end  #match?
  
end # KofNLineMatcher


# ------------------ MAIN - setup -------------- 

# Usage.  
if ARGV.length < 3
  puts("USAGE repaginate.rb matchstring page-prefix outfile [URLbase]")
  Process.exit
end

matchstring = ARGV[0]
pagefile_prefix = ARGV[1]
outfile_name = ARGV[2]
urlbase = (ARGV.length > 3 ? ARGV[3] : "http://sumurl/page=")


# Matchers tuned to each type of report cover page in the document set. 
# Each type is detected by looking for an approximate match (with given edit-distance thresholds) of at least 2 out of 3 of the terms. This works well
DSSmatcher = KofNLineMatcher.new({"SENSITIVE BUT UNCLASSIFIED"=>10, "BUREAU OF DIPLOMATIC SECURITY"=>12, "SPOT REPORT"=>4}, 2)
DSS2matcher = KofNLineMatcher.new({"this report may be in addition to DS SPOT reporting"=>20, "INCIDENT REPORT" => 5, "Task Order" => 4,}, 2) 
Blackwatermatcher = KofNLineMatcher.new({"Blackwater USA" => 5, "After Action Report (AAR)" => 10, "Location/Venue" => 5}, 2)
DSS3matcher = KofNLineMatcher.new({"Case summary" => 5, "Principal Judicial District" => 12, "Nexus:" => 3}, 2)
KBRmatcher = KofNLineMatcher.new({"KBR" => 1, "LOGCAP 111 HQ Operations" => 7, "Serious/Incident Accident Report" => 10}, 2)

# Each type of matcher indicates a different document type
matcher_to_type = { DSSmatcher=>"DSS SPOT Report", 
                    DSS2matcher=>"DSS Incident Report", 
                    DSS3matcher=>"DSS Case Summary", 
                    Blackwatermatcher=>"Blackwater",
                    KBRmatcher=>"KBR" }
                    

# which of these page types denote the first page of a doc?
coverpage_types = Set.new(["DSS SPOT Report", "DSS Incident Report", "DSS Case Summary", "KBR"])


# ------------------ Paged Reader  -------------- 
# Class which encapsulates consuming pages from files, and adding them to current document

class PagedReader
  
  def initialize(pagefile_prefix, startpage)
    @pagefile_prefix = pagefile_prefix
    @nextpagenum = startpage
    @pagefilename = @pagefile_prefix + @nextpagenum.to_s + ".txt"
    new_doc()
  end
  
  def more_pages?
    File.exists?(@pagefilename)
  end
  
  def current_page
    @nextpagenum-1
  end
  
  # load current page and return page content.  also advances to next page
  def next_page
    @page_content = []
    pagefile = File.open(@pagefilename, "r")
    while (l = pagefile.gets)
       @page_content << l
    end
    
    @nextpagenum += 1
    @pagefilename = @pagefile_prefix + @nextpagenum.to_s + ".txt"
    
    return @page_content   
  end
  
  # return contents of document so far
  def doc_content
    @doc_content
  end

  def doc_start_page
     @doc_start_page
  end
  
  def pages_in_doc
    @pages_in_doc
  end
  
  # add current page content to document. returns current doc
  def add_page_to_doc
    @page_content.each { |line| @doc_content += line}
    @pages_in_doc += 1
    if !@doc_start_page
      @doc_start_page = current_page()
    end
    return @doc_content
  end
  
  # clear the current doc, start the next one. initially empty, only add_page_to_doc writes to doc_content
  def new_doc
    @doc_content = ""
    @doc_start_page = nil
    @pages_in_doc = 0
  end
  
end

# ------------------ Loop through all pages -------------- 

# little helper function to write a doc in correct format: "text, uid, doctype, numpages, url"
# creates UID by hashing URL
@docs_written = 0
def write_doc(csvfile, reader, doctype, urlbase)
  urlstring = urlbase + reader.doc_start_page().to_s
  uidstring = Digest::MD5.hexdigest(urlstring)
  csvfile << [ reader.doc_content(), uidstring, doctype, reader.pages_in_doc(), urlstring ]    # write doc
  @docs_written += 1
  puts "Writing document type #{doctype}. Start #{reader.doc_start_page}, pages #{reader.pages_in_doc}"
end

reader = PagedReader.new(pagefile_prefix, 1)
if !reader.more_pages?
  puts("Can't open file #{pagefilename}, aborting.")
  Process.exit()
end

last_pagetype = nil

CSV.open(outfile_name, "w") do |f|
  
  # write header
  f << ["text","uid","type","pages","url"]
  
  # loop until out of pages
  while reader.more_pages?

    page_content = reader.next_page()
    
    # see if this page matches any of the page types above
    pagetype = nil
    matchline = nil
    matcher_to_type.each do |matcher, type|
      if matchline = matcher.match?(page_content)
        pagetype = type
#       puts "Match on page #{reader.current_page}, type #{pagetype}: #{matchline}"
      end
    end
    
    # now we have to distinguish between page matches which start a doc and those that end
  
    # if this is a starting page, or we're switching to an different page type, write current doc 
    # happens BEFORE adding current page  
    # if we don't know what type of page this is, assume it's part of current doc
    if coverpage_types.include?(pagetype) || (pagetype != nil && (pagetype != last_pagetype))

      if reader.pages_in_doc() > 0
        write_doc(f, reader, last_pagetype, urlbase)
      end

      reader.new_doc()
      last_pagetype = pagetype
    end
      
    # add the page we just read to the current document
    reader.add_page_to_doc()
      
    # Blackwater pages may be ending pages. If so, write current doc
    # happens AFTER adding current page
    if pagetype == "Blackwater"
      page_content.each do |line|
        if line.scan("//END//") != [] then

          write_doc(f, reader, "Blackwater", urlbase)

          reader.new_doc()
          last_pagetype = pagetype            
          break
        end
      end      
      
    end
    
  end #page loop
  
  # no more pages = flush out current document (we know we've got at least one page or we would have exited, above)
  if reader.pages_in_doc() > 0
    write_doc(f, reader, last_pagetype, urlbase)
  end

end

puts "Wrote #{@docs_written} documents"