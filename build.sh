#!/bin/bash

function set_paths {
  # change if you have a different config file
  CONFIG_PATH=config.conf
}

function check_valid {
  # source config file
  if [ ! -e $CONFIG_PATH ]; then
    echo "$CONFIG_PATH not found"
    exit 1
  fi

  # Source the config file
  . $CONFIG_PATH

  if [[ -z $site_name || -z $site_url || -z $site_description || -z $site_feed || -z $site_dir || -z $site_posts || -z $site_assets ]]; then
    echo "$CONFIG_PATH missing arguments."
    exit 1
  fi
}

function source_config {

  # set site destination folder
  site_folder=$(grep -oP '(?<=site_dir=).*' $CONFIG_PATH)

  # set site_url
  site_url=$(grep -oP '(?<=site_url=).*' $CONFIG_PATH)

  # make site folder if doesn't exist
  mkdir -p $site_folder

# set posts folder to value in config
  POSTS_PATH=$(grep -oP '(?<=site_posts=).*' $CONFIG_PATH)

  # make posts folder if it doesn't exist
  mkdir -p $POSTS_PATH

  #set feed_name to site_feed value in config
  feed_name=$(grep -oP '(?<=site_feed=).*' $CONFIG_PATH)

  #set site_assets folder
  site_assets=$(grep -oP '(?<=site_assets=).*' $CONFIG_PATH)

  #set site_theme to value in config
  site_theme=$(grep -oP '(?<=site_theme=).*' $CONFIG_PATH)

  touch $site_folder/$feed_name
}

function create_site {

  # START BUILD
  echo "Building $site_name..."

  # copy over themes
  #mkdir -p "$site_dir"/css
  mkdir -p "$site_folder/css"
  cp -r themes/*.css "$site_folder/css/"

  # copy over assets
  mkdir -p "$site_dir/$site_assets"
  cp -r $site_assets/* "$site_dir/$site_assets/"

  #erases site index, start from scratch
  > $site_folder/index.md 

  # build site index
  touch $site_folder/index.md

  # Convert posts to html
  # uncomment next line to list oldest posts from top to bottom
  for file in $site_posts/*.md

  # add them to index in most recent date order
  # this relies on posts being titled in YYYY-MM-DD-name format to work correctly
  # tac may need to be installed on os x or zsh?
  # uncomment next line to print newest posts from top to bottom (instead of above for top to bottom)
  #ls $site_posts/*.md | tac | while read file;
  do

    # get filename
    pattern='*[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-'
    file_name_noprefix="${file/$pattern}"
    file_name=$(basename $file_name_noprefix .md)

    #check if file has optional title in frontmatter
    post_name=$(grep -oP '(?<=title: ).*' $file)
    if [ -z "$post_name" ]; then #no title given, strip from filename
      post_name="${file_name//-/ }"
    fi

    # use date from filename
    post_date="${file:6:10}"

    #check if file has optional css theme (override config) in frontmatter
    post_theme=$(grep -oP '(?<=theme: ).*' $file)
    if [ -z "$post_theme" ]; then
	post_theme=$site_theme
    fi

    # uncomment this section if you prefer flat hierarchy postname.md -> postname.html in single posts folder
    # mkdir -p $site_folder/posts
    # pandoc --resource-path=$site_assets --extract-media=../$site_assets --standalone --template templates/post_template.html -B templates/header.html -A templates/footer.html --metadata theme="../css/$post_theme" --metadata title="$post_name" $file -o $site_folder/posts/$file_name.html
    # echo "[$post_name](posts/$file_name.html)  ">>$site_folder/index.md

    # uncomment this section if you prefer posts to be in their own subfolder so permalinks are website.com/postname/
    mkdir -p $site_folder/$file_name
    echo "Building $post_name"
    pandoc --resource-path=$site_assets --extract-media=../$site_assets --standalone --template templates/post_template.html -B templates/header.html -A templates/footer.html -V site_url="$site_url" -V date="$post_date" -M theme="../css/$post_theme" -M title="$post_name" $file -o $site_folder/$file_name/index.html
    # Add to site index page
    echo "[$post_name]($file_name/)  ">>$site_folder/index.md

    # add date 
    echo "$post_date  ">>$site_folder/index.md
    echo "">>$site_folder/index.md

  done

  # build index
  pandoc --standalone --template templates/site_template.html -s $site_folder/index.md -A templates/footer.html --metadata title="$site_name" --metadata theme="css/$site_theme" -o $site_folder/index.html

  # build all custom pages of any .md files
  for file in pages/*.md; do

    file_name=$(basename $file .md)
    mkdir -p $site_folder/$file_name

    #check if file has optional title in frontmatter
    post_name=$(grep -oP '(?<=title: ).*' $file)
    if [ -z "$post_name" ]; then #no title given, strip from filename
      post_name="${file_name//-/ }"
    fi

    #check if file has optional css theme (override config) in frontmatter
    post_theme=$(grep -oP '(?<=theme: ).*' $file)
    if [ -z "$post_theme" ]; then
	post_theme=$site_theme
    fi

    pandoc --resource-path=$site_assets --extract-media=../$site_assets --standalone --template templates/post_template.html -B templates/header.html -A templates/footer.html -V site_url="$site_url" -V date="$post_date" -M theme="../css/$post_theme" -M title="$post_name" $file -o $site_folder/$file_name/index.html

  done
}

function create_feed {
  # feed meta
  > $site_folder/$feed_name #erases file, start from scratch
  echo '<rss version="2.0">'>> $site_folder/$feed_name
  echo "<channel>" >> $site_folder/$feed_name
  echo "<title>$site_name</title>" >> $site_folder/$feed_name
  echo "<link>$site_url</link>" >> $site_folder/$feed_name
  echo "<description>$site_description</description>" >> $site_folder/$feed_name

  # individual feed items
  for file in $POSTS_PATH/*.md
  do
    echo "<item>" >> $site_folder/$feed_name
    # get individual title
    echo "<title>" >> $site_folder/$feed_name
    title=$(grep -oP '(?<=title: ).*' $file)
    if [ -z "$title" ]; then
      # if no title in frontmatter, use stripped filename
      pattern='*[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-'
      file_name_noprefix="${file/$pattern}"
      file_name=$(basename $file_name_noprefix .md)
      post_name="${file_name//-/ }"
      title=$post_name
    fi
    echo $title >> $site_folder/$feed_name
    echo "</title>" >> $site_folder/$feed_name

    # get individual url
    echo "<link>" >> $site_folder/$feed_name
    echo $site_url/${file// /-} >> $site_folder/$feed_name
    echo "</link>" >> $site_folder/$feed_name
    # use url for guid too
    echo "<guid>" >> $site_folder/$feed_name
    echo $site_url/${file// /-} >> $site_folder/$feed_name
    echo "</guid>" >> $site_folder/$feed_name

    # echo formatted pubdate
    echo "<pubDate>" >> $site_folder/$feed_name
    # thanks to https://lynxbee.com/create-pubdate-tag-in-rss-xml-using-linux-date-command/#.ZA9akY7MJhF
    pubDate=$(grep -oP '(?<=date: ).*' $file)
    date -d "$pubDate" +"%a, %d %b %Y %H:%M:%S %z" >> $site_folder/$feed_name
    echo "</pubDate>" >> $site_folder/$feed_name

    # echo description of each item
    echo "<description>" >> $site_folder/$feed_name
    ## wrap html content in a CDATA for rss 2.0 spec
    echo "<![CDATA[" >> $site_folder/$feed_name

    # if description in frontmatter, use that
    post_description=$(grep -oP '(?<=description: ).*' $file)
    if [ -z "$post_description" ]; then #otherwise, use head of a post
      post_description=$(pandoc --to=plain $file | head)
    fi
    echo "$post_description" >> $site_folder/$feed_name

    echo "]]>" >> $site_folder/$feed_name
    echo "</description>" >> $site_folder/$feed_name

    echo "</item>" >> $site_folder/$feed_name
  done

  echo -e '</channel>
  </rss>' >> $site_folder/$feed_name
}

#-----------------------MAIN--------------------------
set_paths
check_valid
source_config
create_site
create_feed
