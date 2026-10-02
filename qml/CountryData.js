.pragma library

// Country recommendations for the advanced search (AdvancedSearchPage).
// Contains English names plus German translations for localisation.

var countries = [
    { code: "AD", name: "Andorra", de: "Andorra", lat: 42.5, lon: 1.5, borders: ["ES", "FR"], languages: ["Catalan"] },
    { code: "AE", name: "United Arab Emirates", de: "Vereinigte Arabische Emirate", lat: 24, lon: 54, borders: ["OM", "SA"], languages: ["Arabic"] },
    { code: "AF", name: "Afghanistan", de: "Afghanistan", lat: 33, lon: 65, borders: ["CN", "IR", "PK", "TJ", "TM", "UZ"], languages: ["Pashto", "Dari"] },
    { code: "AG", name: "Antigua and Barbuda", de: "Antigua und Barbuda", lat: 17.05, lon: -61.8, borders: [], languages: ["English"] },
    { code: "AL", name: "Albania", de: "Albanien", lat: 41, lon: 20, borders: ["GR", "ME", "MK", "XK"], languages: ["Albanian"] },
    { code: "AM", name: "Armenia", de: "Armenien", lat: 40, lon: 45, borders: ["AZ", "GE", "IR", "TR"], languages: ["Armenian"] },
    { code: "AO", name: "Angola", de: "Angola", lat: -12.5, lon: 18.5, borders: ["CD", "CG", "NA", "ZM"], languages: ["Portuguese"] },
    { code: "AR", name: "Argentina", de: "Argentinien", lat: -34, lon: -64, borders: ["BO", "BR", "CL", "PY", "UY"], languages: ["Spanish"] },
    { code: "AT", name: "Austria", de: "Österreich", lat: 47.3, lon: 13.3, borders: ["CH", "CZ", "DE", "HU", "IT", "LI", "SI", "SK"], languages: ["German"] },
    { code: "AU", name: "Australia", de: "Australien", lat: -27, lon: 133, borders: [], languages: ["English"] },
    { code: "AZ", name: "Azerbaijan", de: "Aserbaidschan", lat: 40.5, lon: 47.5, borders: ["AM", "GE", "IR", "RU", "TR"], languages: ["Azerbaijani"] },
    { code: "BA", name: "Bosnia and Herzegovina", de: "Bosnien und Herzegowina", lat: 44, lon: 18, borders: ["HR", "ME", "RS"], languages: ["Bosnian", "Croatian", "Serbian"] },
    { code: "BB", name: "Barbados", de: "Barbados", lat: 13.17, lon: -59.53, borders: [], languages: ["English"] },
    { code: "BD", name: "Bangladesh", de: "Bangladesch", lat: 24, lon: 90, borders: ["IN", "MM"], languages: ["Bengali"] },
    { code: "BE", name: "Belgium", de: "Belgien", lat: 50.8, lon: 4, borders: ["DE", "FR", "LU", "NL"], languages: ["Dutch", "French", "German"] },
    { code: "BF", name: "Burkina Faso", de: "Burkina Faso", lat: 13, lon: -2, borders: ["BJ", "CI", "GH", "ML", "NE", "TG"], languages: ["French"] },
    { code: "BG", name: "Bulgaria", de: "Bulgarien", lat: 43, lon: 25, borders: ["GR", "MK", "RO", "RS", "TR"], languages: ["Bulgarian"] },
    { code: "BH", name: "Bahrain", de: "Bahrain", lat: 26, lon: 50.55, borders: [], languages: ["Arabic"] },
    { code: "BI", name: "Burundi", de: "Burundi", lat: -3.5, lon: 30, borders: ["CD", "RW", "TZ"], languages: ["Kirundi", "French"] },
    { code: "BJ", name: "Benin", de: "Benin", lat: 9.5, lon: 2.25, borders: ["BF", "NE", "NG", "TG"], languages: ["French"] },
    { code: "BN", name: "Brunei", de: "Brunei", lat: 4.5, lon: 114.67, borders: ["MY"], languages: ["Malay"] },
    { code: "BO", name: "Bolivia", de: "Bolivien", lat: -17, lon: -65, borders: ["AR", "BR", "CL", "PE", "PY"], languages: ["Spanish", "Quechua"] },
    { code: "BR", name: "Brazil", de: "Brasilien", lat: -10, lon: -55, borders: ["AR", "BO", "CO", "GY", "PE", "PY", "SR", "UY", "VE"], languages: ["Portuguese"] },
    { code: "BS", name: "Bahamas", de: "Bahamas", lat: 25.03, lon: -77.4, borders: [], languages: ["English"] },
    { code: "BT", name: "Bhutan", de: "Bhutan", lat: 27.5, lon: 90.5, borders: ["CN", "IN"], languages: ["Dzongkha"] },
    { code: "BW", name: "Botswana", de: "Botsuana", lat: -22, lon: 24, borders: ["NA", "ZA", "ZM", "ZW"], languages: ["English", "Tswana"] },
    { code: "BY", name: "Belarus", de: "Belarus", lat: 53, lon: 28, borders: ["LT", "LV", "PL", "RU", "UA"], languages: ["Belarusian", "Russian"] },
    { code: "BZ", name: "Belize", de: "Belize", lat: 17.25, lon: -88.75, borders: ["GT", "MX"], languages: ["English", "Spanish"] },
    { code: "CA", name: "Canada", de: "Kanada", lat: 60, lon: -95, borders: ["US"], languages: ["English", "French"] },
    { code: "CD", name: "Democratic Republic of the Congo", de: "Demokratische Republik Kongo", lat: -4, lon: 25, borders: ["AO", "BI", "CF", "CG", "RW", "SS", "TZ", "UG", "ZM"], languages: ["French"] },
    { code: "CF", name: "Central African Republic", de: "Zentralafrikanische Republik", lat: 7, lon: 21, borders: ["CD", "CG", "CM", "SD", "SS", "TD"], languages: ["French", "Sango"] },
    { code: "CG", name: "Republic of the Congo", de: "Republik Kongo", lat: -1, lon: 15, borders: ["AO", "CD", "CF", "CM", "GA"], languages: ["French"] },
    { code: "CH", name: "Switzerland", de: "Schweiz", lat: 47, lon: 8, borders: ["AT", "DE", "FR", "IT", "LI"], languages: ["German", "French", "Italian", "Romansh"] },
    { code: "CI", name: "Ivory Coast", de: "Elfenbeinküste", lat: 8, lon: -5, borders: ["BF", "GH", "GN", "LR", "ML"], languages: ["French"] },
    { code: "CL", name: "Chile", de: "Chile", lat: -30, lon: -71, borders: ["AR", "BO", "PE"], languages: ["Spanish"] },
    { code: "CM", name: "Cameroon", de: "Kamerun", lat: 6, lon: 12, borders: ["CF", "CG", "GA", "GQ", "NG", "TD"], languages: ["French", "English"] },
    { code: "CN", name: "China", de: "China", lat: 35, lon: 105, borders: ["AF", "BT", "HK", "IN", "KG", "KP", "KZ", "LA", "MM", "MN", "MO", "NP", "PK", "RU", "TJ", "VN"], languages: ["Chinese"] },
    { code: "CO", name: "Colombia", de: "Kolumbien", lat: 4, lon: -72, borders: ["BR", "EC", "PA", "PE", "VE"], languages: ["Spanish"] },
    { code: "CR", name: "Costa Rica", de: "Costa Rica", lat: 10, lon: -84, borders: ["NI", "PA"], languages: ["Spanish"] },
    { code: "CU", name: "Cuba", de: "Kuba", lat: 21.5, lon: -80, borders: [], languages: ["Spanish"] },
    { code: "CV", name: "Cape Verde", de: "Kap Verde", lat: 16, lon: -24, borders: [], languages: ["Portuguese"] },
    { code: "CY", name: "Cyprus", de: "Zypern", lat: 35, lon: 33, borders: [], languages: ["Greek", "Turkish"] },
    { code: "CZ", name: "Czech Republic", de: "Tschechien", lat: 49.8, lon: 15.5, borders: ["AT", "DE", "PL", "SK"], languages: ["Czech"] },
    { code: "DE", name: "Germany", de: "Deutschland", lat: 51, lon: 9, borders: ["AT", "BE", "CH", "CZ", "DK", "FR", "LU", "NL", "PL"], languages: ["German"] },
    { code: "DJ", name: "Djibouti", de: "Dschibuti", lat: 11.5, lon: 43, borders: ["ER", "ET", "SO"], languages: ["French", "Arabic"] },
    { code: "DK", name: "Denmark", de: "Dänemark", lat: 56, lon: 10, borders: ["DE"], languages: ["Danish"] },
    { code: "DM", name: "Dominica", de: "Dominica", lat: 15.42, lon: -61.33, borders: [], languages: ["English"] },
    { code: "DO", name: "Dominican Republic", de: "Dominikanische Republik", lat: 19, lon: -70.67, borders: ["HT"], languages: ["Spanish"] },
    { code: "DZ", name: "Algeria", de: "Algerien", lat: 28, lon: 3, borders: ["LY", "MA", "ML", "MR", "NE", "TN"], languages: ["Arabic", "French"] },
    { code: "EC", name: "Ecuador", de: "Ecuador", lat: -2, lon: -77.5, borders: ["CO", "PE"], languages: ["Spanish"] },
    { code: "EE", name: "Estonia", de: "Estland", lat: 59, lon: 26, borders: ["LV", "RU"], languages: ["Estonian"] },
    { code: "EG", name: "Egypt", de: "Ägypten", lat: 27, lon: 30, borders: ["IL", "LY", "PS", "SD"], languages: ["Arabic"] },
    { code: "ER", name: "Eritrea", de: "Eritrea", lat: 15, lon: 39, borders: ["DJ", "ET", "SD"], languages: ["Tigrinya", "Arabic"] },
    { code: "ES", name: "Spain", de: "Spanien", lat: 40, lon: -4, borders: ["AD", "FR", "GI", "MA", "PT"], languages: ["Spanish", "Catalan"] },
    { code: "ET", name: "Ethiopia", de: "Äthiopien", lat: 8, lon: 38, borders: ["DJ", "ER", "KE", "SD", "SO", "SS"], languages: ["Amharic"] },
    { code: "FI", name: "Finland", de: "Finnland", lat: 64, lon: 26, borders: ["NO", "RU", "SE"], languages: ["Finnish", "Swedish"] },
    { code: "FJ", name: "Fiji", de: "Fidschi", lat: -18, lon: 175, borders: [], languages: ["English", "Fijian"] },
    { code: "FM", name: "Micronesia", de: "Mikronesien", lat: 6.92, lon: 158.25, borders: [], languages: ["English"] },
    { code: "FO", name: "Faroe Islands", de: "Färöer", lat: 62, lon: -7, borders: [], languages: ["Faroese", "Danish"] },
    { code: "FR", name: "France", de: "Frankreich", lat: 46, lon: 2, borders: ["AD", "BE", "CH", "DE", "ES", "IT", "LU", "MC"], languages: ["French"] },
    { code: "GA", name: "Gabon", de: "Gabun", lat: -1, lon: 11.75, borders: ["CG", "CM", "GQ"], languages: ["French"] },
    { code: "GB", name: "United Kingdom", de: "Vereinigtes Königreich", lat: 54, lon: -2, borders: ["IE"], languages: ["English"] },
    { code: "GD", name: "Grenada", de: "Grenada", lat: 12.12, lon: -61.67, borders: [], languages: ["English"] },
    { code: "GE", name: "Georgia", de: "Georgien", lat: 42, lon: 43.5, borders: ["AM", "AZ", "RU", "TR"], languages: ["Georgian"] },
    { code: "GH", name: "Ghana", de: "Ghana", lat: 8, lon: -2, borders: ["BF", "CI", "TG"], languages: ["English"] },
    { code: "GI", name: "Gibraltar", de: "Gibraltar", lat: 36.13, lon: -5.35, borders: ["ES"], languages: ["English"] },
    { code: "GL", name: "Greenland", de: "Grönland", lat: 72, lon: -40, borders: [], languages: ["Greenlandic", "Danish"] },
    { code: "GM", name: "Gambia", de: "Gambia", lat: 13.47, lon: -16.57, borders: ["SN"], languages: ["English"] },
    { code: "GN", name: "Guinea", de: "Guinea", lat: 11, lon: -10, borders: ["CI", "GW", "LR", "ML", "SL", "SN"], languages: ["French"] },
    { code: "GQ", name: "Equatorial Guinea", de: "Äquatorialguinea", lat: 2, lon: 10, borders: ["CM", "GA"], languages: ["Spanish", "French", "Portuguese"] },
    { code: "GR", name: "Greece", de: "Griechenland", lat: 39, lon: 22, borders: ["AL", "BG", "MK", "TR"], languages: ["Greek"] },
    { code: "GT", name: "Guatemala", de: "Guatemala", lat: 15.5, lon: -90.25, borders: ["BZ", "HN", "MX", "SV"], languages: ["Spanish"] },
    { code: "GW", name: "Guinea-Bissau", de: "Guinea-Bissau", lat: 12, lon: -15, borders: ["GN", "SN"], languages: ["Portuguese"] },
    { code: "GY", name: "Guyana", de: "Guyana", lat: 5, lon: -59, borders: ["BR", "SR", "VE"], languages: ["English"] },
    { code: "HK", name: "Hong Kong", de: "Hongkong", lat: 22.3, lon: 114.2, borders: ["CN"], languages: ["Chinese", "English"] },
    { code: "HN", name: "Honduras", de: "Honduras", lat: 15, lon: -86.5, borders: ["GT", "NI", "SV"], languages: ["Spanish"] },
    { code: "HR", name: "Croatia", de: "Kroatien", lat: 45.2, lon: 15.5, borders: ["BA", "HU", "ME", "RS", "SI"], languages: ["Croatian"] },
    { code: "HT", name: "Haiti", de: "Haiti", lat: 19, lon: -72.42, borders: ["DO"], languages: ["French", "Haitian Creole"] },
    { code: "HU", name: "Hungary", de: "Ungarn", lat: 47, lon: 20, borders: ["AT", "HR", "RO", "RS", "SI", "SK", "UA"], languages: ["Hungarian"] },
    { code: "ID", name: "Indonesia", de: "Indonesien", lat: -5, lon: 120, borders: ["MY", "PG", "TL"], languages: ["Indonesian"] },
    { code: "IE", name: "Ireland", de: "Irland", lat: 53, lon: -8, borders: ["GB"], languages: ["English", "Irish"] },
    { code: "IL", name: "Israel", de: "Israel", lat: 31.5, lon: 34.75, borders: ["EG", "JO", "LB", "PS", "SY"], languages: ["Hebrew", "Arabic"] },
    { code: "IN", name: "India", de: "Indien", lat: 20, lon: 77, borders: ["BD", "BT", "CN", "MM", "NP", "PK"], languages: ["Hindi", "English"] },
    { code: "IQ", name: "Iraq", de: "Irak", lat: 33, lon: 44, borders: ["IR", "JO", "KW", "SA", "SY", "TR"], languages: ["Arabic", "Kurdish"] },
    { code: "IR", name: "Iran", de: "Iran", lat: 32, lon: 53, borders: ["AF", "AM", "AZ", "IQ", "PK", "TM", "TR"], languages: ["Persian"] },
    { code: "IS", name: "Iceland", de: "Island", lat: 65, lon: -18, borders: [], languages: ["Icelandic"] },
    { code: "IT", name: "Italy", de: "Italien", lat: 42.8, lon: 12.8, borders: ["AT", "CH", "FR", "SI", "SM", "VA"], languages: ["Italian"] },
    { code: "JM", name: "Jamaica", de: "Jamaika", lat: 18.25, lon: -77.5, borders: [], languages: ["English"] },
    { code: "JO", name: "Jordan", de: "Jordanien", lat: 31, lon: 36, borders: ["IL", "IQ", "PS", "SA", "SY"], languages: ["Arabic"] },
    { code: "JP", name: "Japan", de: "Japan", lat: 36, lon: 138, borders: [], languages: ["Japanese"] },
    { code: "KE", name: "Kenya", de: "Kenia", lat: 1, lon: 38, borders: ["ET", "SO", "SS", "TZ", "UG"], languages: ["Swahili", "English"] },
    { code: "KG", name: "Kyrgyzstan", de: "Kirgisistan", lat: 41, lon: 75, borders: ["CN", "KZ", "TJ", "UZ"], languages: ["Kyrgyz", "Russian"] },
    { code: "KH", name: "Cambodia", de: "Kambodscha", lat: 13, lon: 105, borders: ["LA", "TH", "VN"], languages: ["Khmer"] },
    { code: "KI", name: "Kiribati", de: "Kiribati", lat: 1.42, lon: 173, borders: [], languages: ["English"] },
    { code: "KM", name: "Comoros", de: "Komoren", lat: -12.17, lon: 44.25, borders: [], languages: ["Comorian", "Arabic", "French"] },
    { code: "KN", name: "Saint Kitts and Nevis", de: "St. Kitts und Nevis", lat: 17.33, lon: -62.75, borders: [], languages: ["English"] },
    { code: "KP", name: "North Korea", de: "Nordkorea", lat: 40, lon: 127, borders: ["CN", "KR", "RU"], languages: ["Korean"] },
    { code: "KR", name: "South Korea", de: "Südkorea", lat: 37, lon: 127.5, borders: ["KP"], languages: ["Korean"] },
    { code: "KW", name: "Kuwait", de: "Kuwait", lat: 29.5, lon: 45.75, borders: ["IQ", "SA"], languages: ["Arabic"] },
    { code: "KZ", name: "Kazakhstan", de: "Kasachstan", lat: 48, lon: 68, borders: ["CN", "KG", "RU", "TM", "UZ"], languages: ["Kazakh", "Russian"] },
    { code: "LA", name: "Laos", de: "Laos", lat: 18, lon: 105, borders: ["CN", "KH", "MM", "TH", "VN"], languages: ["Lao"] },
    { code: "LB", name: "Lebanon", de: "Libanon", lat: 33.8, lon: 35.8, borders: ["IL", "SY"], languages: ["Arabic"] },
    { code: "LC", name: "Saint Lucia", de: "St. Lucia", lat: 13.88, lon: -60.97, borders: [], languages: ["English"] },
    { code: "LI", name: "Liechtenstein", de: "Liechtenstein", lat: 47.2, lon: 9.5, borders: ["AT", "CH"], languages: ["German"] },
    { code: "LK", name: "Sri Lanka", de: "Sri Lanka", lat: 7, lon: 81, borders: [], languages: ["Sinhala", "Tamil"] },
    { code: "LR", name: "Liberia", de: "Liberia", lat: 6.5, lon: -9.5, borders: ["CI", "GN", "SL"], languages: ["English"] },
    { code: "LS", name: "Lesotho", de: "Lesotho", lat: -29.5, lon: 28.5, borders: ["ZA"], languages: ["English", "Sotho"] },
    { code: "LT", name: "Lithuania", de: "Litauen", lat: 56, lon: 24, borders: ["BY", "LV", "PL", "RU"], languages: ["Lithuanian"] },
    { code: "LU", name: "Luxembourg", de: "Luxemburg", lat: 49.8, lon: 6.1, borders: ["BE", "DE", "FR"], languages: ["Luxembourgish", "French", "German"] },
    { code: "LV", name: "Latvia", de: "Lettland", lat: 57, lon: 25, borders: ["BY", "EE", "LT", "RU"], languages: ["Latvian"] },
    { code: "LY", name: "Libya", de: "Libyen", lat: 25, lon: 17, borders: ["DZ", "EG", "NE", "SD", "TD", "TN"], languages: ["Arabic"] },
    { code: "MA", name: "Morocco", de: "Marokko", lat: 32, lon: -5, borders: ["DZ", "ES"], languages: ["Arabic", "French"] },
    { code: "MC", name: "Monaco", de: "Monaco", lat: 43.73, lon: 7.4, borders: ["FR"], languages: ["French"] },
    { code: "MD", name: "Moldova", de: "Moldau", lat: 47, lon: 29, borders: ["RO", "UA"], languages: ["Romanian"] },
    { code: "ME", name: "Montenegro", de: "Montenegro", lat: 42.5, lon: 19.3, borders: ["AL", "BA", "HR", "RS", "XK"], languages: ["Montenegrin", "Serbian"] },
    { code: "MG", name: "Madagascar", de: "Madagaskar", lat: -20, lon: 47, borders: [], languages: ["Malagasy", "French"] },
    { code: "MH", name: "Marshall Islands", de: "Marshallinseln", lat: 9, lon: 168, borders: [], languages: ["Marshallese", "English"] },
    { code: "MK", name: "North Macedonia", de: "Nordmazedonien", lat: 41.6, lon: 21.7, borders: ["AL", "BG", "GR", "RS", "XK"], languages: ["Macedonian", "Albanian"] },
    { code: "ML", name: "Mali", de: "Mali", lat: 17, lon: -4, borders: ["BF", "CI", "DZ", "GN", "MR", "NE", "SN"], languages: ["French"] },
    { code: "MM", name: "Myanmar", de: "Myanmar", lat: 22, lon: 98, borders: ["BD", "CN", "IN", "LA", "TH"], languages: ["Burmese"] },
    { code: "MN", name: "Mongolia", de: "Mongolei", lat: 46, lon: 105, borders: ["CN", "RU"], languages: ["Mongolian"] },
    { code: "MO", name: "Macau", de: "Macau", lat: 22.2, lon: 113.55, borders: ["CN"], languages: ["Chinese", "Portuguese"] },
    { code: "MR", name: "Mauritania", de: "Mauretanien", lat: 20, lon: -12, borders: ["DZ", "ML", "SN"], languages: ["Arabic", "French"] },
    { code: "MT", name: "Malta", de: "Malta", lat: 35.9, lon: 14.4, borders: [], languages: ["Maltese", "English"] },
    { code: "MU", name: "Mauritius", de: "Mauritius", lat: -20.28, lon: 57.55, borders: [], languages: ["English", "French"] },
    { code: "MV", name: "Maldives", de: "Malediven", lat: 3.25, lon: 73, borders: [], languages: ["Dhivehi"] },
    { code: "MW", name: "Malawi", de: "Malawi", lat: -13.5, lon: 34, borders: ["MZ", "TZ", "ZM"], languages: ["English", "Chichewa"] },
    { code: "MX", name: "Mexico", de: "Mexiko", lat: 23, lon: -102, borders: ["BZ", "GT", "US"], languages: ["Spanish"] },
    { code: "MY", name: "Malaysia", de: "Malaysia", lat: 2.5, lon: 112.5, borders: ["BN", "ID", "TH"], languages: ["Malay", "English"] },
    { code: "MZ", name: "Mozambique", de: "Mosambik", lat: -18.25, lon: 35, borders: ["MW", "SZ", "TZ", "ZA", "ZM", "ZW"], languages: ["Portuguese"] },
    { code: "NA", name: "Namibia", de: "Namibia", lat: -22, lon: 17, borders: ["AO", "BW", "ZA", "ZM"], languages: ["English"] },
    { code: "NE", name: "Niger", de: "Niger", lat: 16, lon: 8, borders: ["BF", "BJ", "DZ", "LY", "ML", "NG", "TD"], languages: ["French"] },
    { code: "NG", name: "Nigeria", de: "Nigeria", lat: 10, lon: 8, borders: ["BJ", "CM", "NE", "TD"], languages: ["English"] },
    { code: "NI", name: "Nicaragua", de: "Nicaragua", lat: 13, lon: -85, borders: ["CR", "HN"], languages: ["Spanish"] },
    { code: "NL", name: "Netherlands", de: "Niederlande", lat: 52.5, lon: 5.8, borders: ["BE", "DE"], languages: ["Dutch"] },
    { code: "NO", name: "Norway", de: "Norwegen", lat: 62, lon: 10, borders: ["FI", "RU", "SE"], languages: ["Norwegian"] },
    { code: "NP", name: "Nepal", de: "Nepal", lat: 28, lon: 84, borders: ["CN", "IN"], languages: ["Nepali"] },
    { code: "NR", name: "Nauru", de: "Nauru", lat: -0.53, lon: 166.92, borders: [], languages: ["Nauruan", "English"] },
    { code: "NZ", name: "New Zealand", de: "Neuseeland", lat: -41, lon: 174, borders: [], languages: ["English", "Maori"] },
    { code: "OM", name: "Oman", de: "Oman", lat: 21, lon: 57, borders: ["AE", "SA", "YE"], languages: ["Arabic"] },
    { code: "PA", name: "Panama", de: "Panama", lat: 9, lon: -80, borders: ["CO", "CR"], languages: ["Spanish"] },
    { code: "PE", name: "Peru", de: "Peru", lat: -10, lon: -76, borders: ["BO", "BR", "CL", "CO", "EC"], languages: ["Spanish", "Quechua"] },
    { code: "PG", name: "Papua New Guinea", de: "Papua-Neuguinea", lat: -6, lon: 147, borders: ["ID"], languages: ["English", "Tok Pisin"] },
    { code: "PH", name: "Philippines", de: "Philippinen", lat: 13, lon: 122, borders: [], languages: ["Filipino", "English"] },
    { code: "PK", name: "Pakistan", de: "Pakistan", lat: 30, lon: 70, borders: ["AF", "CN", "IN", "IR"], languages: ["Urdu", "English"] },
    { code: "PL", name: "Poland", de: "Polen", lat: 52, lon: 20, borders: ["BY", "CZ", "DE", "LT", "RU", "SK", "UA"], languages: ["Polish"] },
    { code: "PR", name: "Puerto Rico", de: "Puerto Rico", lat: 18.25, lon: -66.5, borders: [], languages: ["Spanish", "English"] },
    { code: "PS", name: "Palestine", de: "Palästina", lat: 31.9, lon: 35.2, borders: ["EG", "IL", "JO"], languages: ["Arabic"] },
    { code: "PT", name: "Portugal", de: "Portugal", lat: 39.5, lon: -8, borders: ["ES"], languages: ["Portuguese"] },
    { code: "PW", name: "Palau", de: "Palau", lat: 7.5, lon: 134.5, borders: [], languages: ["Palauan", "English"] },
    { code: "PY", name: "Paraguay", de: "Paraguay", lat: -23, lon: -58, borders: ["AR", "BO", "BR"], languages: ["Spanish", "Guarani"] },
    { code: "QA", name: "Qatar", de: "Katar", lat: 25.5, lon: 51.25, borders: ["SA"], languages: ["Arabic"] },
    { code: "RO", name: "Romania", de: "Rumänien", lat: 46, lon: 25, borders: ["BG", "HU", "MD", "RS", "UA"], languages: ["Romanian"] },
    { code: "RS", name: "Serbia", de: "Serbien", lat: 44, lon: 21, borders: ["BA", "BG", "HR", "HU", "ME", "MK", "RO", "XK"], languages: ["Serbian"] },
    { code: "RU", name: "Russia", de: "Russland", lat: 60, lon: 100, borders: ["AZ", "BY", "CN", "EE", "FI", "GE", "KP", "KZ", "LT", "LV", "MN", "NO", "PL", "UA"], languages: ["Russian"] },
    { code: "RW", name: "Rwanda", de: "Ruanda", lat: -2, lon: 30, borders: ["BI", "CD", "TZ", "UG"], languages: ["Kinyarwanda", "French", "English"] },
    { code: "SA", name: "Saudi Arabia", de: "Saudi-Arabien", lat: 25, lon: 45, borders: ["AE", "IQ", "JO", "KW", "OM", "QA", "YE"], languages: ["Arabic"] },
    { code: "SB", name: "Solomon Islands", de: "Salomonen", lat: -8, lon: 159, borders: [], languages: ["English"] },
    { code: "SC", name: "Seychelles", de: "Seychellen", lat: -4.58, lon: 55.67, borders: [], languages: ["English", "French"] },
    { code: "SD", name: "Sudan", de: "Sudan", lat: 15, lon: 30, borders: ["CF", "EG", "ER", "ET", "LY", "SS", "TD"], languages: ["Arabic", "English"] },
    { code: "SE", name: "Sweden", de: "Schweden", lat: 62, lon: 15, borders: ["FI", "NO"], languages: ["Swedish"] },
    { code: "SG", name: "Singapore", de: "Singapur", lat: 1.37, lon: 103.8, borders: [], languages: ["English", "Malay", "Chinese", "Tamil"] },
    { code: "SI", name: "Slovenia", de: "Slowenien", lat: 46.1, lon: 14.8, borders: ["AT", "HR", "HU", "IT"], languages: ["Slovenian"] },
    { code: "SK", name: "Slovakia", de: "Slowakei", lat: 48.7, lon: 19.5, borders: ["AT", "CZ", "HU", "PL", "UA"], languages: ["Slovak"] },
    { code: "SL", name: "Sierra Leone", de: "Sierra Leone", lat: 8.5, lon: -11.5, borders: ["GN", "LR"], languages: ["English"] },
    { code: "SM", name: "San Marino", de: "San Marino", lat: 43.94, lon: 12.46, borders: ["IT"], languages: ["Italian"] },
    { code: "SN", name: "Senegal", de: "Senegal", lat: 14, lon: -14, borders: ["GM", "GN", "GW", "ML", "MR"], languages: ["French"] },
    { code: "SO", name: "Somalia", de: "Somalia", lat: 10, lon: 49, borders: ["DJ", "ET", "KE"], languages: ["Somali", "Arabic"] },
    { code: "SR", name: "Suriname", de: "Suriname", lat: 4, lon: -56, borders: ["BR", "GY"], languages: ["Dutch"] },
    { code: "SS", name: "South Sudan", de: "Südsudan", lat: 7, lon: 30, borders: ["CD", "CF", "ET", "KE", "SD", "UG"], languages: ["English"] },
    { code: "ST", name: "São Tomé and Príncipe", de: "São Tomé und Príncipe", lat: 1, lon: 7, borders: [], languages: ["Portuguese"] },
    { code: "SV", name: "El Salvador", de: "El Salvador", lat: 13.83, lon: -88.92, borders: ["GT", "HN"], languages: ["Spanish"] },
    { code: "SY", name: "Syria", de: "Syrien", lat: 35, lon: 38, borders: ["IL", "IQ", "JO", "LB", "TR"], languages: ["Arabic"] },
    { code: "SZ", name: "Eswatini", de: "Eswatini", lat: -26.5, lon: 31.5, borders: ["MZ", "ZA"], languages: ["English", "Swazi"] },
    { code: "TD", name: "Chad", de: "Tschad", lat: 15, lon: 19, borders: ["CF", "CM", "LY", "NE", "NG", "SD"], languages: ["French", "Arabic"] },
    { code: "TG", name: "Togo", de: "Togo", lat: 8, lon: 1.17, borders: ["BF", "BJ", "GH"], languages: ["French"] },
    { code: "TH", name: "Thailand", de: "Thailand", lat: 15, lon: 100, borders: ["KH", "LA", "MM", "MY"], languages: ["Thai"] },
    { code: "TJ", name: "Tajikistan", de: "Tadschikistan", lat: 39, lon: 71, borders: ["AF", "CN", "KG", "UZ"], languages: ["Tajik"] },
    { code: "TL", name: "East Timor", de: "Osttimor", lat: -8.87, lon: 125.73, borders: ["ID"], languages: ["Portuguese", "Tetum"] },
    { code: "TM", name: "Turkmenistan", de: "Turkmenistan", lat: 40, lon: 60, borders: ["AF", "IR", "KZ", "UZ"], languages: ["Turkmen"] },
    { code: "TN", name: "Tunisia", de: "Tunesien", lat: 34, lon: 9, borders: ["DZ", "LY"], languages: ["Arabic", "French"] },
    { code: "TO", name: "Tonga", de: "Tonga", lat: -20, lon: -175, borders: [], languages: ["Tongan", "English"] },
    { code: "TR", name: "Turkey", de: "Türkei", lat: 39, lon: 35, borders: ["AM", "AZ", "BG", "GE", "GR", "IQ", "IR", "SY"], languages: ["Turkish"] },
    { code: "TT", name: "Trinidad and Tobago", de: "Trinidad und Tobago", lat: 11, lon: -61, borders: [], languages: ["English"] },
    { code: "TV", name: "Tuvalu", de: "Tuvalu", lat: -8, lon: 178, borders: [], languages: ["English", "Tuvaluan"] },
    { code: "TW", name: "Taiwan", de: "Taiwan", lat: 23.7, lon: 121, borders: [], languages: ["Chinese"] },
    { code: "TZ", name: "Tanzania", de: "Tansania", lat: -6, lon: 35, borders: ["BI", "CD", "KE", "MW", "MZ", "RW", "UG", "ZM"], languages: ["Swahili", "English"] },
    { code: "UA", name: "Ukraine", de: "Ukraine", lat: 49, lon: 32, borders: ["BY", "HU", "MD", "PL", "RO", "RU", "SK"], languages: ["Ukrainian"] },
    { code: "UG", name: "Uganda", de: "Uganda", lat: 1, lon: 32, borders: ["CD", "KE", "RW", "SS", "TZ"], languages: ["English", "Swahili"] },
    { code: "US", name: "United States", de: "Vereinigte Staaten", lat: 38, lon: -97, borders: ["CA", "MX"], languages: ["English"] },
    { code: "UY", name: "Uruguay", de: "Uruguay", lat: -33, lon: -56, borders: ["AR", "BR"], languages: ["Spanish"] },
    { code: "UZ", name: "Uzbekistan", de: "Usbekistan", lat: 41, lon: 64, borders: ["AF", "KG", "KZ", "TJ", "TM"], languages: ["Uzbek"] },
    { code: "VA", name: "Vatican City", de: "Vatikanstadt", lat: 41.9, lon: 12.45, borders: ["IT"], languages: ["Italian", "Latin"] },
    { code: "VC", name: "Saint Vincent and the Grenadines", de: "St. Vincent und die Grenadinen", lat: 13.25, lon: -61.2, borders: [], languages: ["English"] },
    { code: "VE", name: "Venezuela", de: "Venezuela", lat: 8, lon: -66, borders: ["BR", "CO", "GY"], languages: ["Spanish"] },
    { code: "VN", name: "Vietnam", de: "Vietnam", lat: 16, lon: 106, borders: ["CN", "KH", "LA"], languages: ["Vietnamese"] },
    { code: "VU", name: "Vanuatu", de: "Vanuatu", lat: -16, lon: 167, borders: [], languages: ["Bislama", "English", "French"] },
    { code: "WS", name: "Samoa", de: "Samoa", lat: -13.58, lon: -172.33, borders: [], languages: ["Samoan", "English"] },
    { code: "XK", name: "Kosovo", de: "Kosovo", lat: 42.6, lon: 20.9, borders: ["AL", "ME", "MK", "RS"], languages: ["Albanian", "Serbian"] },
    { code: "YE", name: "Yemen", de: "Jemen", lat: 15, lon: 48, borders: ["OM", "SA"], languages: ["Arabic"] },
    { code: "ZA", name: "South Africa", de: "Südafrika", lat: -29, lon: 24, borders: ["BW", "LS", "MZ", "NA", "SZ", "ZW"], languages: ["English", "Afrikaans", "Zulu"] },
    { code: "ZM", name: "Zambia", de: "Sambia", lat: -15, lon: 30, borders: ["AO", "BW", "CD", "MW", "MZ", "NA", "TZ", "ZW"], languages: ["English"] },
    { code: "ZW", name: "Zimbabwe", de: "Simbabwe", lat: -20, lon: 30, borders: ["BW", "MZ", "ZA", "ZM"], languages: ["English", "Shona"] }
];

var _byCode = null;

function findCountry(code) {
    if (_byCode === null) {
        _byCode = {};
        for (var i = 0; i < countries.length; i++) {
            _byCode[countries[i].code] = countries[i];
        }
    }
    var key = String(code || "").toUpperCase();
    return _byCode[key] || null;
}

// Helper: returns the localised name (German for German locales, otherwise English)
function getLocalizedName(country) {
    if (!country) return "";
    var lang = Qt.locale().name; // e.g. "de_DE", "en_US"
    if (lang && lang.indexOf("de") === 0) {
        return country.de || country.name;
    }
    return country.name; // fall back to English
}

// Great-circle distance in km (haversine)
function distanceKm(lat1, lon1, lat2, lon2) {
    var R = 6371;
    var dLat = (lat2 - lat1) * Math.PI / 180;
    var dLon = (lon2 - lon1) * Math.PI / 180;
    var a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
            Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
            Math.sin(dLon / 2) * Math.sin(dLon / 2);
    var c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
}

function languageMap() {
    var map = {};
    for (var i = 0; i < countries.length; i++) {
        map[countries[i].code] = countries[i].languages;
    }
    return map;
}

function sharesLanguage(a, b) {
    for (var i = 0; i < a.length; i++) {
        if (b.indexOf(a[i]) !== -1) {
            return true;
        }
    }
    return false;
}

function scoreCountries(userCode) {
    var user = findCountry(userCode);
    if (!user) {
        return [];
    }
    var scored = [];
    for (var i = 0; i < countries.length; i++) {
        var c = countries[i];
        var score = 0;
        if (c.code === user.code) {
            score = 10000;
        } else {
            if (sharesLanguage(c.languages, user.languages)) {
                score += 3000;
            }
            if (user.borders.indexOf(c.code) !== -1) {
                score += 2000;
            }
            score += Math.max(0, 1000 - distanceKm(user.lat, user.lon, c.lat, c.lon) / 15);
        }
        scored.push({ name: getLocalizedName(c), iso_code: c.code, score: score });
    }
    scored.sort(function(a, b) {
        if (b.score !== a.score) {
            return b.score - a.score;
        }
        return a.name < b.name ? -1 : (a.name > b.name ? 1 : 0);
    });
    return scored;
}

function homeProfile(userCode) {
    var user = findCountry(userCode);
    if (!user) {
        return null;
    }
    var languages = [];
    for (var i = 0; i < user.languages.length; i++) {
        languages.push(user.languages[i].toLowerCase());
    }
    return { code: user.code, languages: languages };
}

function languageMatches(home, station) {
    var own = String(station.language || "").toLowerCase();
    var i;
    if (own.length > 0) {
        for (i = 0; i < home.languages.length; i++) {
            if (own.indexOf(home.languages[i]) !== -1) {
                return true;
            }
        }
        return false;
    }
    var country = findCountry(station.countrycode);
    if (!country) {
        return false;
    }
    for (i = 0; i < country.languages.length; i++) {
        if (home.languages.indexOf(country.languages[i].toLowerCase()) !== -1) {
            return true;
        }
    }
    return false;
}

function sortByHome(stations, home, ownCountryFactor, popularityOf) {
    if (typeof popularityOf !== "function") {
        throw new Error("sortByHome: popularityOf fehlt (z.B. RadioApi.popularity übergeben)");
    }
    var factor = ownCountryFactor > 0 ? ownCountryFactor : 1;
    var decorated = [];
    for (var i = 0; i < stations.length; i++) {
        var s = stations[i];
        var own = String(s.countrycode || "").toUpperCase() === home.code;
        decorated.push({
            station: s,
            group: languageMatches(home, s) ? 1 : 0,
            weight: popularityOf(s) * (own ? factor : 1)
        });
    }
    decorated.sort(function(a, b) {
        if (a.group !== b.group) {
            return b.group - a.group;
        }
        if (a.weight !== b.weight) {
            return b.weight - a.weight;
        }
        var na = String(a.station.name || "").toLowerCase();
        var nb = String(b.station.name || "").toLowerCase();
        return na < nb ? -1 : (na > nb ? 1 : 0);
    });
    for (var j = 0; j < decorated.length; j++) {
        stations[j] = decorated[j].station;
    }
    return stations;
}

function rankCountries(userCode, limit) {
    var scored = scoreCountries(userCode);
    var max = (limit > 0 && limit < scored.length) ? limit : scored.length;
    var result = [];
    for (var i = 0; i < max; i++) {
        result.push({ name: scored[i].name, iso_code: scored[i].iso_code });
    }
    return result;
}
