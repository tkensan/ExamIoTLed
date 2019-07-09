import tornado.ioloop
import tornado.web


class MainHandler(tornado.web.RequestHandler):
    def get(self):
        self.write("Hello, Get")

def make_webapp():
    return tornado.web.Application([
        (r"/", MainHandler), ])

if __name__ == "__main__":
    webapp = make_webapp()
    webapp.listen(8888)
    tornado.ioloop.IOLoop.current().start()
