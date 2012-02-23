# Iraq contractor incidents 2005-2007, original PDFs and splitting scripts 

These are the files used to produce iraq-contractor-incidents source file for analysis in the Overview prototype. The original PDFs are <a href="https://www.documentcloud.org/public/search/group:%20gawker%20source:%20%22state%22">on DocumentCloud</a>, stored here for convenience. The resulting .csv is available as part of the <a href="https://github.com/overview/overview-sample-files/">
Overview sample files</a>. 

The most interesting thing here is the repaginate.rb script, which does fuzzy coverpage detection (and can also take a list of manual coverpages where a PDF should be split, as in the january-june-2005-manual-coverpages file). The scripts in this project also demonstrate how to extract text from (pre-OCR'd) PDFs using DocSplit.

To recreate the final csv, run:

	./extract-text-all.sh
	./repaginate-all.sh
	
# copyleft

GPLv3

# contact

need help? ask!

https://twitter.com/overviewproject

