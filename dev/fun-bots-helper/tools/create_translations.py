import sys

def createTranslations(pathToFiles):
	settings_definition = pathToFiles + "ext/shared/Settings/SettingsDefinition.lua"
	index_html = pathToFiles + "WebUI/index.html"
	listOfJsTranslationFiles = [
		pathToFiles + "WebUI/Classes/EntryElement.js",
		pathToFiles + "WebUI/Classes/BotEditor.js"
	]

	language_file = pathToFiles + "ext/shared/Languages/DEFAULT.lua"
	language_file_en = pathToFiles + "ext/shared/Languages/en_EN.lua"
	language_file_js = pathToFiles + "WebUI/languages/DEFAULT.js"
	language_file_en_js = pathToFiles + "WebUI/languages/en_EN.js"

	# other files with Language content : Language:I18N(

	listOfTranslationFiles = [
		pathToFiles + "ext/Client/ClientNodeEditor.lua",
		pathToFiles + "ext/Server/BotSpawner.lua",
		pathToFiles + "ext/Server/UIServer.lua",
		pathToFiles + "ext/Server/NodeCollection.lua"]

	with open(settings_definition, "r") as inFile:
		readoutActive = False
		allSettings = []
		setting = {}
		numberOfSettings = 0
		for line in inFile.read().splitlines():
			if "Elements = {" in line:
				readoutActive = True
			if readoutActive:
				if "Text = " in line:
					setting["Text"] = line.split('"')[-2]
				if "Default =" in line:
					setting["Default"] = line.split('=')[-1].replace(",", "").replace(" ", "")
				if "Description =" in line:
					setting["Description"] = line.split('"')[-2]
				if "Category =" in line:
					setting["Category"] = line.split('"')[-2]
				if "}," in line:
					allSettings.append(setting)
					numberOfSettings = numberOfSettings + 1
					setting = {}
		# add last setting
		allSettings.append(setting)
		numberOfSettings = numberOfSettings + 1
		print("import done")
		setting = {}

		outFileLines = []
		with open(language_file, "w") as outFile:
			outFileLines.append("local code = 'xx_XX' -- Add/replace the xx_XX here with your language code (like de_DE, en_US, or other)!\n")
			lastCategory = None
			for setting in allSettings:
				if setting["Category"] != lastCategory:
					if lastCategory != None:
						outFileLines.append("")
					outFileLines.append("--"+setting["Category"])
					lastCategory = setting["Category"]
				outFileLines.append("Language:add(code, \""+setting["Text"] + "\", \"\")")
				outFileLines.append("Language:add(code, \""+setting["Description"] + "\", \"\")")
			
			# scan the other files
			for fileName in listOfTranslationFiles:
				outFileLines.append("\n-- Strings of "+ fileName)
				with open(fileName, "r") as fileWithTranslation:
					for line in fileWithTranslation.read().splitlines():
						if "Language:I18N(" in line:
							translation = line.split("Language:I18N(")[1]
							translation = translation.split(translation[0])[1]
							if translation != "":
								newLine = "Language:add(code, \""+ translation + "\", \"\")"
								if newLine not in outFileLines:
									outFileLines.append("Language:add(code, \""+ translation + "\", \"\")")
			for line in outFileLines:
				outFile.write(line + "\n")
			print("write done")
		
		outFileLines = []
		with open(language_file_en, "w") as outFile:
			outFileLines.append("local code = 'en_EN' -- This file is autogenerated!\n")
			lastCategory = None
			for setting in allSettings:
				if setting["Category"] != lastCategory:
					if lastCategory != None:
						outFileLines.append("")
					outFileLines.append("--"+setting["Category"])
					lastCategory = setting["Category"]
				outFileLines.append("Language:add(code, \""+setting["Text"] + "\", \"" + setting["Text"] + "\")")
				outFileLines.append("Language:add(code, \""+setting["Description"] + "\", \"" + setting["Description"] + "\")")
			
			# scan the other files
			for fileName in listOfTranslationFiles:
				outFileLines.append("\n-- Strings of "+ fileName)
				with open(fileName, "r") as fileWithTranslation:
					for line in fileWithTranslation.read().splitlines():
						if "Language:I18N(" in line:
							translation = line.split("Language:I18N(")[1]
							translation = translation.split(translation[0])[1]
							if translation != "":
								newLine = "Language:add(code, \""+ translation + "\", \"" + translation + "\")"
								if newLine not in outFileLines:
									outFileLines.append("Language:add(code, \""+ translation + "\", \"" + translation + "\")")
			for line in outFileLines:
				outFile.write(line + "\n")
			print("write done")

	with open(index_html, "r") as inFileHtml:
		allHtmlTranslations = []
		for line in inFileHtml.read().splitlines():
			if "data-lang=\"" in line:
				translationHtml = line.split("data-lang=\"")[1].split("\"")[0]
				if translationHtml not in allHtmlTranslations:
					allHtmlTranslations.append(translationHtml)
		for fileName in listOfJsTranslationFiles:
			with open(fileName, "r") as fileWithTranslation:
				for line in fileWithTranslation.read().splitlines():
					if "I18N('" in line:
						translation = line.split("I18N('")[1]
						translation = translation.split("'")[0]
						if translation not in allHtmlTranslations:
							allHtmlTranslations.append(translation)

		with open(language_file_js, "w") as outFileHtml:
			outFileHtml.write("""Language['xx_XX'] /* Add/replace the xx_XX here with your language code (like de_DE, en_US, or other)! */ = {
	"__LANGUAGE_INFO": {
		"name": "English",
		"author": "Unknown",
		"version": "1.0.0"
	},
""")
			for translation in allHtmlTranslations:
				outFileHtml.write("	\""+ translation + "\": \"\",\n")
			outFileHtml.write("};")
		
		with open(language_file_en_js, "w") as outFileHtml:
			outFileHtml.write("""Language['en_EN'] /* This file is autogenerated! */ = {
	"__LANGUAGE_INFO": {
		"name": "English",
		"author": "Unknown",
		"version": "1.0.0"
	},
""")
			for translation in allHtmlTranslations:
				outFileHtml.write("	\""+ translation + "\": \"" + translation + "\",\n")
			outFileHtml.write("};")

if __name__ == "__main__":
	pathToFiles = "./"
	if len(sys.argv) > 1:
		pathToFiles = sys.argv[1]
	createTranslations(pathToFiles)