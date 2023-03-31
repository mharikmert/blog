FROM jekyll/jekyll as builder

COPY . /src/jekyll

# jekyll docker image uses 'jekyll' as user
# so change all permissions in the folder to jekyll
RUN chown -R jekyll /src/jekyll

WORKDIR /src/jekyll

RUN jekyll clean

RUN jekyll build 

FROM lipanski/docker-static-website:latest

COPY --from=builder /src/jekyll/_site .