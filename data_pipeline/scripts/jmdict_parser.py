import xml.etree.ElementTree as ET

XML_LANG = "{http://www.w3.org/XML/1998/namespace}lang"


def iter_entries(xml_path):
    context = ET.iterparse(xml_path, events=("end",))
    for event, elem in context:
        if elem.tag != "entry":
            continue
        expressions = [e.text for e in elem.findall("./k_ele/keb") if e.text]
        readings = [e.text for e in elem.findall("./r_ele/reb") if e.text]
        glosses = []
        for gloss in elem.findall("./sense/gloss"):
            lang = gloss.attrib.get(XML_LANG)
            if lang == "kor" and gloss.text:
                glosses.append(gloss.text.strip())
        yield expressions, readings, glosses
        elem.clear()
