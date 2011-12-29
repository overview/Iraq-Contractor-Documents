#/usr/bin/sh
ruby repaginate.rb x textpages/january-june-2005_ docs-january-june-2005.csv "https://www.documentcloud.org/documents/271270-january-june-2005.html#document/p"
ruby repaginate.rb x textpages/june-december-2005_ docs-june-december-2005.csv "https://www.documentcloud.org/documents/271271-june-december-2005.html#document/p"
ruby repaginate.rb x textpages/january-to-june-2006_ docs-january-june-2006.csv "https://www.documentcloud.org/documents/271273-january-to-june-2006.html#document/p"
ruby repaginate.rb x textpages/june-to-december-2006_ docs-june-december-2006.csv "https://www.documentcloud.org/documents/271274-june-to-december-2007.html#document/p"
ruby repaginate.rb x textpages/january-to-june-2007_ docs-january-june-2007.csv "https://www.documentcloud.org/documents/271276-january-to-june-2007.html#document/p"
ruby repaginate.rb x textpages/june-to-december-2007_ docs-june-december-2007.csv "https://www.documentcloud.org/documents/271277-june-to-december-2007.html#document/p"

cp docs-january-june-2005.csv iraq-contractor-incidents.csv
sed 1d docs-june-december-2005.csv >> iraq-contractor-incidents.csv
sed 1d docs-january-june-2006.csv >> iraq-contractor-incidents.csv
sed 1d docs-june-december-2006.csv >> iraq-contractor-incidents.csv
sed 1d docs-january-june-2007.csv >> iraq-contractor-incidents.csv
sed 1d docs-june-december-2007.csv  >> iraq-contractor-incidents.csv
