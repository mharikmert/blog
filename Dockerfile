FROM jekyll/jekyll as builder

COPY . /src/jekyll

# jekyll docker image uses 'jekyll' as user
# so change all permissions in the folder to jekyll
RUN chown -R jekyll /src/jekyll

WORKDIR /src/jekyll

RUN jekyll clean

RUN jekyll build 

FROM nginx:alpine

COPY --from=builder /src/jekyll/_site /usr/share/nginx/html/

COPY default.conf /etc/nginx/conf.d/default.conf