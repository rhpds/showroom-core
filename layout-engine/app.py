import os
import sys
import yaml

from flask import Flask, render_template, url_for, send_from_directory, request, redirect

app = Flask(__name__)
app.config["url_path"] = os.getenv("URL_PATH", "/")
app.logger.info('Serving content on path: %s', app.config["url_path"])

app.config["config_path"] = os.getenv("LAYOUT_CONFIG_PATH", "config/2-column.yaml")
# app.config["config_path"] = "config/single-page.yaml"
# app.config["config_path"] = "config/2-column-stacked-left.yaml"
# app.config["config_path"] = "config/2-column-stacked-right.yaml"
# app.config["config_path"] = "config/2-column-tabs-left.yaml"
# app.config["config_path"] = "config/2-column-tabs-right.yaml"
# app.config["config_path"] = "config/2-column-both-tabs-stacked.yaml"
# app.config["config_path"] = "config/2-column-triple-stacked-left.yaml"
# app.config["config_path"] = "config/2-column-triple-stacked-right.yaml"

with open(app.config["config_path"]) as stream:
    app.logger.info('Opening config file: %s', app.config["config_path"])
    try:
        data = yaml.safe_load(stream)
        # from_mapping will only read uppercase root keys, any children are lowercase
        # ie. data["LAYOUT"]["columns"][0]["url"]
        data = {k.upper():v for k,v in data.items()}
        app.config.from_mapping(data)
    except yaml.YAMLError as exc:
        sys.exit(exc)

@app.route(app.config["url_path"])
def showroom():
    static_path = app.config["url_path"]
    # If serving the app with no path (/) remove the slash so static paths
    # don't look like .//static/split.css
    if static_path == "/":
        static_path = ""

    return render_template('index.html', layout=app.config["LAYOUT"], url_path=static_path)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
