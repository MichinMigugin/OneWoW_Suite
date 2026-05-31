# -*- coding: utf-8 -*-
"""Patch OWSL locale Lua files: replace values for each OWSL_* key using per-locale string lists."""
import re
from pathlib import Path

PAT = re.compile(r'(\["(OWSL_[^"]+)"\]\s*=\s*")((?:[^"\\]|\\.)*)(")')

BASE = Path(__file__).parent


def extract_keys():
    text = (BASE / "enUS.lua").read_text(encoding="utf-8")
    return re.findall(r'\["(OWSL_[^"]+)"\]\s*=', text)


def patch_file(name: str, values: list[str]) -> None:
    keys = extract_keys()
    if len(keys) != len(values):
        raise SystemExit(f"{name}: keys {len(keys)} vs values {len(values)}")
    trans = dict(zip(keys, values))
    path = BASE / name
    text = path.read_text(encoding="utf-8")

    def repl(m):
        key = m.group(2)
        if key not in trans:
            return m.group(0)
        v = trans[key]
        esc = v.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")
        return m.group(1) + esc + m.group(4)

    new_text = PAT.sub(repl, text)
    path.write_text(new_text, encoding="utf-8")


# --- German (deDE) ---
DE = [
    "Hauptliste", "Liste existiert bereits", "Liste nicht gefunden", "Zielname existiert bereits",
    "Hauptliste kann nicht gelöscht werden", "Ungültige Gegenstands-ID",
    "Einkaufsliste", "Listen", "Rezept wählen: %s", "Herstellbare Gegenstände in: %s",
    "Export: %s", "Einkaufsliste importieren", "Einstellungen",
    "+ Neue Liste", "Alle scannen", "Gegenstand hierher ziehen", "Per ID hinzufügen", "Importieren",
    "HINZUFÜGEN", "HERSTELLEN", "Erstellen", "Abbrechen", "Umbenennen", "Löschen", "Schließen",
    "Liste erstellen", "Zur *-Liste hinzufügen", "Mehr hinzufügen", "Einstellungen", "Zurück", "Speichern",
    "Twinks suchen", "Suche:", "Menge:", "ID:", "Neuer Listenname:", "Importierte Liste %s", "Sprache:",
    "%d/%d (Gesamt)", "%d/%d (Twinks)", "Nicht gefunden",
    "Einkaufsliste", "Klicken zum Umbenennen", "Alle ungelösten Gegenstände scannen",
    "Durchsucht deine Gegenstände und 20.000+ Datenbankeinträge",
    "Löst exakte Namen automatisch auf", "WICHTIG: 2–3 mal drücken für beste Ergebnisse",
    "API-Verzögerungen können mehrere Scans erfordern", "(Wegen API-Verzögerung 2–3 mal drücken)",
    "Gegenstände importieren", "Crafting-Materialien in diesen Formaten einfügen:",
    "16x Drachenkieferholz  ODER  16x",
    "10x Goldener Karpfen             Drachenkieferholz",
    "Twinks suchen",
    "Wenn aktiv, durchsucht alle Charaktere (Taschen, Banken, Kriegsmeer-Bank, Ausrüstung usw.) nach Gegenständen dieser Liste",
    "Klicken zum Ein-/Ausklappen der Details", "Ungelöster Gegenstand",
    "Gegenstands-ID eingeben oder Scannen zum Auflösen", "Einkaufslisten-Gegenstand",
    "Rechtsklick: In andere Liste verschieben", "Shift+Klick: Zur Auktionssuche hinzufügen",
    "Zur Menge hinzufügen", "Zahl eingeben, die zur aktuellen Menge addiert wird",
    "Beispiel: Aktuell 50, +98 = 148", "Gegenstands-ID eingeben",
    "ID eingeben und Enter zum Aktivieren des Trackings",
    "IDs auf wowhead.com oder in Spiel-Links finden", "Diesen Gegenstand herstellen",
    "Crafting-Zutaten zur Einkaufsliste hinzufügen", "1 Rezept verfügbar: %s", "%d Rezepte verfügbar",
    "Aus Liste entfernen", "Herstellauftrag löschen", "Liste löschen",
    "Löscht auch %d Herstellauftrag/Herstellaufträge", "Mehrere Herstellaufträge",
    "Dieser Gegenstand wird an mehreren Stellen hergestellt:", "Gesamt benötigt: %d",
    "Neue Einkaufsliste", "Erstellt eine neue Liste mit diesen Reagenzien",
    "Zur aktiven Liste hinzufügen", "Fügt die Reagenzien zur aktuell mit Stern markierten Liste hinzu",
    "Einkaufsliste öffnen", "Klicken zum Öffnen der Einkaufsliste", "Standardliste",
    "Neue Gegenstände landen standardmäßig hier", "Als Standardliste setzen",
    "Klicken, um diese Liste als Standard für neue Gegenstände zu nutzen",
    "Abgedeckte Menge: %d/%d", "Herstellaufträge decken diese Menge bereits ab",
    "Vorhandene Herstellaufträge: %d/%d",
    "Für diesen Gegenstand existiert bereits ein Herstellauftrag auf dieser Liste",
    "Verschieben nach…", "Herstellauftrag erstellen", "Herstellauftrag umbenennen", "Liste umbenennen",
    "Herstellauftrag exportieren", "Liste exportieren", "Herstellauftrag löschen", "Liste löschen",
    "Gegenstands-ID oder Namen für Herstellauftrag eingeben:", "Neuen Listennamen eingeben:",
    "„%s“ umbenennen in:", "„%s“ löschen?", "Dies kann nicht rückgängig gemacht werden.",
    "Eine Liste namens „%s“ existiert bereits.", "Diese Zutaten zur vorhandenen Liste hinzufügen?",
    "Gegenstands-ID eingeben:", "Zur aktuellen Menge (%d) addieren:",
    "Mehrere Rezepte können dies herstellen. Eins wählen:",
    " (Bekannt bei: %s +%d weitere)", " (Bekannt bei: %s)", " (Keinem Charakter bekannt)",
    "%d herstellbare Gegenstände gefunden. HERSTELLEN klicken, um in Zutaten zu zerlegen:",
    "Benötigte Menge: %d", "1 Rezept: %s", "%d Rezepte verfügbar",
    "Text unten markieren und kopieren (Strg+C):", "Crafting-Materialliste unten einfügen:",
    "Unterstützte Formate:\n  16x Drachenkieferholz   ODER   16x\n  10x Goldener Karpfen                  Drachenkieferholz",
    "Einkaufsliste nicht initialisiert", "„%s“ zur Auktionssuche hinzugefügt",
    "Bitte zuerst das Auktionshaus öffnen", "„%s“ aufgelöst zu %s (ID: %d)",
    "Bitte eine gültige Gegenstands-ID eingeben", "Verschieben fehlgeschlagen: Liste nicht gefunden",
    "Gegenstand in Quellliste nicht gefunden", "%s von %s nach %s verschoben",
    "Verschieben fehlgeschlagen: %s", "Ungültige Gegenstands-ID: %d",
    "Manueller Herstellauftrag erstellt für: %s", "Herstellauftrag konnte nicht erstellt werden",
    "Gegenstand auf die Schaltfläche ziehen", "Ungültige Gegenstands-ID",
    "%d zu %s addiert (Neue Summe: %d)", "Menge konnte nicht aktualisiert werden",
    "Bitte eine gültige positive Zahl eingeben", "Keine Rezepte für diesen Gegenstand",
    "Keine Zutaten für dieses Rezept", "Herstellauftrag fehlgeschlagen: %s",
    "Herstellauftrag unter „%s“ mit %d Zutat%s%s erstellt", "Keine Zutaten hinzugefügt",
    "Berufsdaten nicht bereit. Bitte zuerst Berufe scannen", "Keine Gegenstände in der aktuellen Liste",
    "Keine herstellbaren Gegenstände in dieser Liste", "%d Gegenstände gescannt – keiner herstellbar",
    "%s zu %s hinzugefügt", "%d erledigte Gegenstände entfernt", "Export der Liste fehlgeschlagen",
    "Bitte einen Listennamen eingeben", "Bitte Text zum Importieren einfügen",
    "Vorhandene Liste „%s“ wird verwendet", "Keine gültigen Gegenstände zum Importieren",
    "Lade %d Gegenstände vom Server…", "%d Gegenstände mit IDs importiert, %d nur nach Namen",
    "%d Gegenstände nur nach Namen hinzugefügt. IDs können später manuell ergänzt werden.",
    "Keine ungelösten Gegenstände zum Scannen", "Scanne %d ungelöste Gegenstände…",
    "Scan abgeschlossen! Aufgelöst: %d, Teiltreffer: %d, Nicht gefunden: %d", "Suche nach „%s“…",
    "Exakter Treffer! Automatisch aufgelöst zu %s (ID: %d)", "%d Teilübereinstimmung(en) gefunden:",
    " - Teilübereinstimmungen gefunden:", "ID kopieren, in das ID-Feld einfügen, dann Enter",
    "Keine Treffer in Besitz oder Datenbank.", "ID manuell von wowhead.com eingeben",
    "Einkaufslisten-Hinweis", "Linksklick: Einkaufsliste öffnen", "Rechtsklick: Schließen",
    "Gegenstands-Tooltips aktivieren", "Listeninfos beim Überfahren von Gegenständen anzeigen",
    "ALLGEMEIN", "Sprache:", "Sprachauswahl", "Bevorzugte Sprache wählen. Änderungen sofort aktiv.",
    "Thema:", "Farbschema", "Farbschema wählen. Änderungen sofort aktiv.",
    "ADDON-STATUS", "Twink-/Bankzugriff", "Kriegsmeer-Bank-Zugriff",
    "Herstellbarkeit & Rezeptdaten", "Verfügbar", "Nicht verfügbar",
    "OVERLAY-EINSTELLUNGEN", "Einkaufswagen-Overlay aktivieren", "Position:",
    "Skalierung: %.1f", "Deckkraft: %.1f", "TASTENBEFEHLE", "Einkaufsliste umschalten:",
    "Gegenstand zur Standardliste hinzufügen:", "Nicht belegt",
    "In WoW unter Tastenbelegung > OneWoW einrichten",
    "Maus über Gegenstand und Taste drücken, um ihn zur Standard-Einkaufsliste hinzuzufügen",
    "Erkannt", "Nicht erkannt", "Minikarten-Button anzeigen", "Overlay auf Taschen-Gegenständen",
    "Schaltflächen im Berufe-UI", "Schaltfläche im Auktionshaus",
    "Benötigte Menge festlegen:", "Menge des Herstellauftrags festlegen:",
    "%d Gegenstände (%d erledigt)",
    "English", "한국어", "Français", "Deutsch", "Русский", "Español",
    "Gegenstand %d",
    "Herstellbar von: %s", "Herstellbar von: %s (+%d weitere)", "Herstellbar (kein bekannter Hersteller)",
    "... und %d weitere", "Rezept %d",
    "Aus Einkaufsliste entfernt", "Zur Einkaufsliste hinzugefügt", "Herstellauftrag erstellt",
    "%s – %d Zutaten", "Scan abgeschlossen", "%d Gegenstände automatisch aufgelöst!",
    "Gegenstand automatisch aufgelöst",
    "Oben links", "Oben rechts", "Unten links", "Unten rechts", "Mitte",
    "Einkaufsliste", "Klicken zum Öffnen der Einkaufsliste",
    "Einkaufsliste", "Liste erstellen", "Zur *-Liste hinzufügen", "Zu Liste hinzufügen…",
    "Zu bestimmter Liste hinzufügen", "Reagenzien in eine gewählte Liste legen",
    "Klicken zum Öffnen", "Zum Verschieben ziehen", "%d Listen", "%d Gegenstände",
    "Minikarten-Button", "Minikarten-Button ein- oder ausblenden.", "Symbol-Thema",
    "Fraktionssymbol für die Minikarte wählen.", "Aktuell", "Horde", "Allianz", "Neutral",
]

# --- Spanish (esES) ---
ES = [
    "Lista principal", "La lista ya existe", "Lista no encontrada", "El nombre ya existe",
    "No se puede borrar la lista principal", "ID de objeto no válido",
    "Lista de compras", "Listas", "Seleccionar receta: %s", "Objetos fabricables en: %s",
    "Exportar: %s", "Importar lista de compras", "Ajustes",
    "+ Nueva lista", "Escanear todo", "Arrastra el objeto aquí", "Añadir por ID", "Importar",
    "AÑADIR", "FABRICAR", "Crear", "Cancelar", "Renombrar", "Eliminar", "Cerrar",
    "Crear lista", "Añadir a lista *", "Añadir más", "Ajustes", "Atrás", "Guardar",
    "Buscar alts", "Buscar:", "Cant.:", "ID:", "Nombre de lista nueva:", "Lista importada %s", "Idioma:",
    "%d/%d (Total)", "%d/%d (Alts)", "No encontrado",
    "Lista de compras", "Clic para renombrar la lista", "Escanear todos los objetos sin resolver",
    "Busca en tus objetos y en más de 20 000 entradas de la base de datos",
    "Resuelve automáticamente coincidencias exactas de nombre", "IMPORTANTE: pulsa 2–3 veces para mejores resultados",
    "Los retrasos de la API pueden requerir varios escaneos", "(Pulsa 2–3 veces por retraso de la API)",
    "Importar objetos", "Pega materiales de artesanía en estos formatos:",
    "16x Madera de pino dragón  O  16x",
    "10x Carpa dorada             Madera de pino dragón",
    "Buscar alts",
    "Si está activo, busca en todos los personajes (mochilas, bancos, banco de banda, equipo, etc.)",
    "Clic para expandir o contraer detalles", "Objeto sin resolver",
    "Introduce ID de objeto o pulsa Escanear para resolver", "Objeto de la lista de compras",
    "Clic derecho: mover a otra lista", "Mayús+Clic: añadir a la búsqueda de subastas",
    "Añadir a la cantidad", "Introduce un número para sumar a la cantidad actual",
    "Ejemplo: actual 50, +98 = 148", "Introduce ID de objeto",
    "Escribe la ID y pulsa Entrar para activar el seguimiento",
    "IDs en wowhead.com o en enlaces del juego", "Fabricar este objeto",
    "Añade ingredientes a una lista de compras", "1 receta disponible: %s", "%d recetas disponibles",
    "Quitar de la lista", "Eliminar orden de fabricación", "Eliminar lista",
    "También eliminará %d orden(es) de fabricación", "Varias órdenes de fabricación",
    "Este objeto se fabrica en varios sitios:", "Total necesario: %d",
    "Nueva lista de compras", "Crea una lista nueva con los reactivos de esta receta",
    "Añadir a la lista activa", "Añade los reactivos a la lista marcada con estrella",
    "Abrir lista de compras", "Clic para abrir la interfaz", "Lista predeterminada",
    "Los objetos nuevos van aquí por defecto", "Establecer como lista predeterminada",
    "Clic para usar esta lista como predeterminada para objetos nuevos",
    "Cantidad cubierta: %d/%d", "Las órdenes de fabricación ya cubren esta cantidad",
    "Órdenes existentes: %d/%d",
    "Ya existe una orden de fabricación para este objeto en esta lista",
    "Mover a…", "Crear orden de fabricación", "Renombrar orden", "Renombrar lista",
    "Exportar orden", "Exportar lista", "Eliminar orden", "Eliminar lista",
    "Introduce ID o nombre para la orden:", "Introduce el nombre de la nueva lista:",
    "Renombrar «%s» a:", "¿Eliminar «%s»?", "No se puede deshacer.",
    "Ya existe una lista llamada «%s».", "¿Añadir estos ingredientes a la lista existente?",
    "Introduce ID de objeto:", "Añadir a la cantidad actual (%d):",
    "Varias recetas pueden fabricar esto. Elige una:",
    " (Conocida por: %s +%d más)", " (Conocida por: %s)", " (Desconocida por todos)",
    "Se encontraron %d objetos fabricables. Pulsa FABRICAR para desglosar:",
    "Cantidad necesaria: %d", "1 receta: %s", "%d recetas disponibles",
    "Selecciona y copia el texto inferior (Ctrl+C):", "Pega tu lista de materiales abajo:",
    "Formatos admitidos:\n  16x Madera de pino dragón   O   16x\n  10x Carpa dorada                  Madera de pino dragón",
    "Lista de compras no inicializada", "«%s» añadido a la búsqueda de subastas",
    "Abre primero la casa de subastas", "«%s» resuelto a %s (ID: %d)",
    "Introduce un ID de objeto válido", "Error al mover: lista no encontrada",
    "Objeto no encontrado en la lista de origen", "Movido %s de %s a %s",
    "Error al mover: %s", "ID de objeto no válida: %d",
    "Orden manual creada para: %s", "No se pudo crear la orden",
    "Arrastra un objeto a la tecla", "ID de objeto no válida",
    "Añadido %d a %s (nuevo total: %d)", "No se pudo actualizar la cantidad",
    "Introduce un número positivo válido", "No hay recetas para este objeto",
    "No hay ingredientes para esta receta", "Error al crear la orden: %s",
    "Orden creada bajo «%s» con %d ingrediente%s%s", "No se añadieron ingredientes",
    "Datos de profesión no listos. Escanea profesiones primero", "No hay objetos en la lista actual",
    "No hay objetos fabricables en esta lista", "Escaneados %d objetos: ninguno fabricable",
    "Añadido %s a %s", "Eliminados %d objetos completados", "Error al exportar la lista",
    "Introduce un nombre de lista", "Pega texto para importar",
    "Usando la lista existente «%s»", "No hay objetos válidos para importar",
    "Cargando %d objetos del servidor…", "Importados %d con ID, %d solo por nombre",
    "%d objetos solo por nombre. Puedes buscar IDs y actualizar después.",
    "No hay objetos sin resolver para escanear", "Escaneando %d objetos sin resolver…",
    "¡Escaneo completo! Resueltos: %d, parciales: %d, no encontrados: %d", "Buscando «%s»…",
    "¡Coincidencia exacta! Resuelto a %s (ID: %d)", "Se encontraron %d coincidencias parciales:",
    " - Coincidencias parciales:", "Copia un ID, pégalo en el campo y pulsa Entrar",
    "Sin coincidencias en posesión o en la base de datos.", "Introduce el ID manualmente desde wowhead.com",
    "Aviso de lista de compras", "Clic izquierdo: abrir lista", "Clic derecho: descartar",
    "Activar tooltips de objetos", "Mostrar información de la lista al pasar el ratón",
    "GENERAL", "Idioma:", "Selección de idioma", "Elige tu idioma. Los cambios son instantáneos.",
    "Tema:", "Tema de color", "Elige un tema de color. Cambios instantáneos.",
    "ESTADO DEL ADDON", "Acceso a alts/banco", "Acceso al banco de banda",
    "Fabricabilidad y datos de recetas", "Disponible", "No disponible",
    "AJUSTES DE SUPERPOSICIÓN", "Activar superposición del carrito", "Posición:",
    "Escala: %.1f", "Opacidad: %.1f", "ATAJOS", "Alternar lista de compras:",
    "Añadir objeto a la lista predeterminada:", "Sin asignar",
    "Configura en Teclas > categoría OneWoW",
    "Pasa el ratón sobre un objeto y pulsa la tecla para añadirlo a tu lista predeterminada",
    "Detectado", "No detectado", "Mostrar botón del minimapa", "Superposición en objetos de las bolsas",
    "Botones en la interfaz de profesiones", "Botón en la casa de subastas",
    "Establecer cantidad necesaria:", "Establecer cantidad de la orden:",
    "%d objetos (%d completados)",
    "English", "한국어", "Français", "Deutsch", "Русский", "Español",
    "Objeto %d",
    "Fabricable por: %s", "Fabricable por: %s (+%d más)", "Fabricable (sin artesanos conocidos)",
    "... y %d más", "Receta %d",
    "Quitado de la lista", "Añadido a la lista", "Orden de fabricación creada",
    "%s – %d ingredientes", "Escaneo completo", "¡%d objetos resueltos automáticamente!",
    "Objeto resuelto automáticamente",
    "Arriba izquierda", "Arriba derecha", "Abajo izquierda", "Abajo derecha", "Centro",
    "Lista de compras", "Clic para abrir la lista",
    "Lista de compras", "Crear lista", "Añadir a lista *", "Añadir a lista…",
    "Añadir a una lista concreta", "Añade los reactivos a la lista que elijas",
    "Clic para abrir", "Arrastra para mover", "%d listas", "%d objetos",
    "Botón del minimapa", "Mostrar u ocultar el botón del minimapa.", "Tema del icono",
    "Elige el icono de facción del minimapa.", "Actual", "Horda", "Alianza", "Neutral",
]

if __name__ == "__main__":
    patch_file("deDE.lua", DE)
    patch_file("esES.lua", ES)
    try:
        from owsl_fr_ru_ko import FR, RU, KO
    except ImportError:
        print("owsl_fr_ru_ko.py missing; only deDE/esES applied")
    else:
        patch_file("frFR.lua", FR)
        patch_file("ruRU.lua", RU)
        patch_file("koKR.lua", KO)
    print("done")
