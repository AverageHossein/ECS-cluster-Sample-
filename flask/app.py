from flask import Flask, jsonify

app = Flask(__name__)

@app.route("/")
def hello_world():
    print("request!")
    return jsonify({"healthy": True})

if __name__ == '__main__':
      app.run(host='0.0.0.0', port=8080)