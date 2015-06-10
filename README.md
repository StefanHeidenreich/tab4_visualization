# tab4_visualization

This project derives from an EU-funded research project on visualizing political communicative spaces on Twitter.
The backend (server) part is to be found under the rails subdirectory, the frontend (browser) part comprises all other files.

## Sample request

### Original (url-encoded)
http://test.tazaldoo.com/hashtrends/report.json?utf8=%E2%9C%93&scopes=111745%2C66529%2C49857%2C111809%2C111873%2C111825%2C111793%2C66609%2C66593%2C66545%2C66273%2C66497%2C66449%2C111633%2C66721%2C66641%2C14305%2C111985%2C66657%2C66337%2C111697%2C111905%2C111889%2C111937%2C1505%2C111601%2C111569%2C66753%2C111649%2C66689%2C111505%2C66577%2C66561%2C66385%2C66481%2C111857%2C111953&sample=1&exclude=%23cdu%2C%23csu%2C%23spd%2C%23gr%C3%BCne%2C%23gruene%2C%23gr%C3%BCnen%2C%23gruenen%2C%23linke%2C%23afd%2C%23fdp%2C%23piraten%2C%23piratenpartei%2C%23swv%2C%23npd%2C%23btw13%2C%23btw%2C%23btw2013%2C%23bundestag%2C%23merkel%2C%23steinbr%C3%BCck%2C%23wahlkampf%2C%23bundestagswahl%2C%23seehofer%2C%23br%C3%BCderle%2C%23lindner%2C%23kipping%2C%23g%C3%B6ringeckardt%2C%23riexinger%2C%23r%C3%B6sler%2C%23schl%C3%B6mer%2C%23sigmargabriel%2C%23trittin&resolution=hourly&days=2

### Decoded
http://test.tazaldoo.com/hashtrends/report.json?utf8=✓&scopes=111745,66529,49857,111809,111873,111825,111793,66609,66593,66545,66273,66497,66449,111633,66721,66641,14305,111985,66657,66337,111697,111905,111889,111937,1505,111601,111569,66753,111649,66689,111505,66577,66561,66385,66481,111857,111953&sample=1&exclude=#cdu,#csu,#spd,#grüne,#gruene,#grünen,#gruenen,#linke,#afd,#fdp,#piraten,#piratenpartei,#swv,#npd,#btw13,#btw,#btw2013,#bundestag,#merkel,#steinbrück,#wahlkampf,#bundestagswahl,#seehofer,#brüderle,#lindner,#kipping,#göringeckardt,#riexinger,#rösler,#schlömer,#sigmargabriel,#trittin&resolution=hourly&days=2

### Parameters
- scopes: Comma-separated list of the scope IDs used to identify individual Twitter scopes (e.g. "global search for keyword '#sigmargabriel'")
- sample: (1/0)
- exclude: Excluded hashtags, used to filter out the keywords that were searched for, in order to get only emerging topics and not static ones
- resolution: what time frame to use as a unit (hourly/daily)
- days: How many days should be covered (an integer)
