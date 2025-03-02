from flask import Flask, jsonify, request, Response
from bs4 import BeautifulSoup
import requests
import re
from tqdm import tqdm
import threading
import schedule
import time
import requests
from bs4 import BeautifulSoup
import urllib.request
from urllib.parse import urlparse, parse_qs
import re
import mysql.connector

headers = {"User-Agent": "Mozilla/5.0 (Windows NT 6.3; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/44.0.2403.157 Safari/537.36"}
mydb = mysql.connector.connect(
    host="127.0.0.1",
    user="root",
    password="0000",
    database="Homer"
)

app = Flask(__name__)

def get_news_from_database(keyword):
    cursor = mydb.cursor(dictionary=True)
    sql = "SELECT * FROM news WHERE keyword = %s"
    val = (keyword,)
    cursor.execute(sql, val)
    news_data = cursor.fetchall()
    cursor.close()
    return news_data

def remove_keyword_from_database(keyword):
    cursor = mydb.cursor()
    cursor.execute("SELECT id FROM keywords WHERE keyword = %s", (keyword,))
    result = cursor.fetchone()
    if result:
        keyword_id = result[0]
        cursor.execute("SELECT id FROM news WHERE keyword = %s", (keyword,))
        news_ids = [row[0] for row in cursor.fetchall()]

        sql = "DELETE FROM keywords WHERE keyword = %s"
        val = (keyword,)
        cursor.execute(sql, val)

        sql = "DELETE FROM news WHERE keyword = %s"
        cursor.execute(sql, val)

        mydb.commit()
        cursor.close()
        return "Keyword '{}' removed successfully.".format(keyword)
    else:
        cursor.close()
        return "Keyword '{}' not found.".format(keyword)


def makePgNum(num):
    if num == 1:
        return num
    elif num == 0:
        return num+1
    else:
        return num+9*(num-1)

def makeUrl(search, start_pg, end_pg):
    urls = []
    for i in range(start_pg, end_pg + 1):
        page = makePgNum(i)
        url = "https://search.naver.com/search.naver?where=news&sm=tab_pge&query=" + str(search) + "&start=" + str(page)
        urls.append(url)
    return urls    

def news_attrs_crawler(articles,attrs):
    attrs_content=[]
    for i in articles:
        attrs_content.append(i.attrs[attrs])
    return attrs_content

def news_contents_crawler(news_url):
    contents=[]
    for i in news_url:
        news = requests.get(i)
        news_html = BeautifulSoup(news.text,"html.parser")
        contents.append(news_html.find_all('p'))
    return contents

def subscribe_articles_crawler(url, subscribe):
    res = requests.get(url, headers=headers)
    soup = BeautifulSoup(res.text, 'lxml')
    newslist = soup.select(".press_ranking_list")
    cursor = mydb.cursor()

    cursor.execute("SELECT title FROM subscribe_articles")
    existing_titles = [row[0] for row in cursor.fetchall()]

    for news in newslist:
        lis = news.findAll("li")
        for li in lis:
            if li.select_one(".list_ranking_num") is not None:
                news_ranking = li.select_one(".list_ranking_num").text
                news_title = li.select_one(".list_title").text
                news_link = li.select_one("._es_pc_link").get("href")
                if (li.select_one(".list_view") is None):
                    news_see = "0"
                else:
                    news_see = li.select_one(".list_view").text
                numbers = re.findall(r'\d+', news_see)
                news_see = ''.join(numbers)

                if news_title not in existing_titles:
                    sql = "INSERT INTO subscribe_articles (ranking, title, link, views, subscribe) VALUES (%s, %s, %s, %s, %s)"
                    val = (news_ranking, news_title, news_link, news_see, subscribe)
                    cursor.execute(sql, val)
                    mydb.commit()

                    cursor.execute("SELECT * FROM view")
                    max_views = cursor.fetchone()
                    if max_views is None:
                        max_views = 1000
                    else:
                        max_views = max_views[0]
                    if int(news_see) > int(max_views):
                        send_notification_to_client(subscribe, news_title, news_see)

    cursor.close()

def send_notification_to_client(subscribe, title, views):
    print(f"Alert: The article '{title}' in '{subscribe}' with {views} views has been found!")

def articles_crawler(url, keyword):
    original_html = requests.get(url)
    html = BeautifulSoup(original_html.text, "html.parser")
    
    articles = html.find_all("div", class_='news_area')
        
    keyword_articles = {'titles': [], 'links': []}
    cursor = mydb.cursor()
    cursor.execute("SELECT COUNT(*) FROM news")
    row_count = cursor.fetchone()[0]
    if row_count == 0:
        cursor.execute("ALTER TABLE news AUTO_INCREMENT = 1")

    for news in articles:
        title = news.find("a", class_="news_tit").text.strip()
        link = news.find("a", class_="news_tit")["href"]

        sql = "SELECT * FROM homer.news WHERE title = %s AND keyword = %s"
        val = (title, keyword)
        cursor.execute(sql, val)
        result = cursor.fetchone()

        if result is None:
            keyword_articles['titles'].append(title)
            keyword_articles['links'].append(link)
            sql = "INSERT INTO news (title, link, keyword) VALUES (%s, %s, %s)"
            val = (title, link, keyword)
            cursor.execute(sql, val)

    mydb.commit()
    cursor.close()

def crawl_news_for_keyword(keyword):
    global news_data
    url = makeUrl(keyword, 1, 3)
    for u in url:
        articles_crawler(u,keyword)

def crawl_news_for_subscribe(subscribe):
    global subscribe_news_data
    url = "https://media.naver.com/press/{}/ranking?type=popular".format(id[subscribe])
    subscribe_articles_crawler(url,subscribe)

def crawl_news_for_all_keywords():
    cursor = mydb.cursor()
    cursor.execute("SELECT * FROM keywords")
    keywords = cursor.fetchall()
    cursor.close()

    if keywords:
        for keyword in keywords:
            crawl_news_for_keyword(keyword[1])

def crawl_news_for_all_subscribe():
    cursor = mydb.cursor(dictionary=True)
    cursor.execute("DELETE FROM subscribe_articles")
    cursor.execute("SELECT * FROM subscribes")
    subscribed_media = cursor.fetchall()
    
    if subscribed_media:
        for media in subscribed_media:
            crawl_news_for_subscribe(media['subscribe'])

    cursor.close()

def crawl_news_job():
    crawl_news_for_all_keywords()
    current_time = time.strftime("%Y-%m-%d %H:%M:%S", time.localtime())
    print("Crawling completed at:", current_time)

def crawl_subscribe_job():
    crawl_news_for_all_subscribe()
    current_time = time.strftime("%Y-%m-%d %H:%M:%S", time.localtime())
    print("subscribe_Crawling completed at:", current_time)

def run_schedule():
    while True:
        schedule.run_pending()
        time.sleep(1)

def is_keyword_exist(keyword):
    cursor = mydb.cursor()
    sql = "SELECT * FROM keywords WHERE keyword = %s"
    val = (keyword,)
    cursor.execute(sql, val)
    result = cursor.fetchone()
    cursor.close()
    return result is not None

@app.route('/add_keyword', methods=['POST'])
def add_keyword():
    data = request.json
    keyword = data.get('keyword')

    if is_keyword_exist(keyword):
        return jsonify({'message': 'Keyword already exists.'}), 400
    cursor = mydb.cursor()
    sql = "INSERT INTO keywords (keyword) VALUES (%s)"
    val = (keyword,)
    cursor.execute(sql, val)
    mydb.commit()
    cursor.close()
    crawl_news_for_keyword(keyword)

    return jsonify({'message': 'Keyword added successfully.'}), 200

@app.route('/set_views', methods=['POST'])
def set_views():
    data = request.json
    max_views = data.get('max_views')

    cursor = mydb.cursor()

    cursor.execute("SELECT * FROM view")
    result = cursor.fetchone()

    if result:
        cursor.execute("UPDATE view SET view = %s", (max_views,))
    else:
        cursor.execute("INSERT INTO view (view) VALUES (%s)", (max_views,))

    mydb.commit()
    cursor.close()

    crawl_news_for_all_subscribe()

    return jsonify({'message': 'min_views set successfully.'}), 200

@app.route('/get_views', methods=['GET'])
def get_views():
    cursor = mydb.cursor()
    cursor.execute("SELECT view FROM view")
    view_data = cursor.fetchall()
    cursor.close()

    view = [str(view[0]) for view in view_data]
    
    return jsonify({'view': view}), 200

@app.route('/add_subscribe', methods=['POST'])
def add_subscribe():
    data = request.json
    subscribe = data.get('subscribe')
    
    if subscribe not in id.keys():
        return jsonify({'message': 'Wrong name.'}), 404
    
    cursor = mydb.cursor()
    cursor.execute("START TRANSACTION")
    cursor.execute("SELECT * FROM subscribes WHERE subscribe = %s", (subscribe,))
    result = cursor.fetchone()
    if result:
        cursor.close()
        return jsonify({'message': 'Subscribe already exists.'}), 400
    
    try:
        cursor.execute("INSERT INTO subscribes (subscribe) VALUES (%s)", (subscribe,))
        print('ok')
        mydb.commit()
        cursor.close()
        print('ok')
        crawl_news_for_subscribe(subscribe)
        print('크롤링 완료')
        
        return jsonify({'message': 'Subscribe added successfully.'}), 200
    except Exception as e:
        return jsonify({'message': str(e)}), 500

@app.route('/add_memo', methods=['POST'])
def add_memo():
    data = request.json
    id = data.get('title')
    memo = data.get('memo')

    cursor = mydb.cursor(dictionary=True)
    cursor.execute("SELECT * FROM scrap_news WHERE title = %s", (id,))
    scrap_data = cursor.fetchone()

    if scrap_data:
        cursor.execute("INSERT INTO memo (news_id, memo) VALUES (%s, %s)", (id, memo))
        mydb.commit()
        cursor.close()

        return jsonify({'message': 'Memo added successfully.'}), 200
    else:
        cursor.close()
        return jsonify({'message': 'Scrap name not found.'}), 404

@app.route('/')
def index():
    return '안녕하세요! Homer 입니다.'

@app.route('/remove_subscribe', methods=['POST'])
def remove_subscribe():
    data = request.json
    subscribe = data.get('subscribe')
    cursor = mydb.cursor()
    cursor.execute("SELECT * FROM subscribes WHERE subscribe = %s", (subscribe,))
    result = cursor.fetchone()
    print('ok')
    if result:
        cursor.execute("DELETE FROM subscribe_articles WHERE subscribe = %s", (subscribe,))
        cursor.execute("DELETE FROM subscribes WHERE subscribe = %s", (subscribe,))
        mydb.commit()
        cursor.close()
        
        return jsonify({'message': 'Subscribe removed successfully.'}), 200
    else:
        cursor.close()
        return jsonify({'message': 'Subscribe not found.'}), 400

@app.route('/remove_keyword', methods=['POST'])
def remove_keyword():
    data = request.json
    keyword = data.get('keyword')
    cursor = mydb.cursor()
    cursor.execute("SELECT * FROM keywords WHERE keyword = %s", (keyword,))
    result = cursor.fetchone()
    
    if result:
        cursor.execute("DELETE FROM news WHERE keyword = %s", (keyword,))
        cursor.execute("DELETE FROM keywords WHERE keyword = %s", (keyword,))
        cursor.execute("SET @num := 0;")
        cursor.execute("UPDATE keywords SET id = @num := (@num+1);")
        cursor.execute("ALTER TABLE homer.keywords AUTO_INCREMENT = 1;")
        mydb.commit()
        cursor.close()
        
        return jsonify({'message': 'Keyword removed successfully.'}), 200
    else:
        cursor.close()
        return jsonify({'message': 'Keyword not found.'}), 400

@app.route('/get_memos', methods=['GET'])
def get_memos():
    news_id = request.args.get('news_id')
    cursor = mydb.cursor(dictionary=True)
    cursor.execute("SELECT * FROM memo WHERE news_id = %s", (news_id,))
    memos = cursor.fetchall()
    cursor.close()

    memo_list = []
    for memo in memos:
        memo_data = {
            'id': memo['id'],
            'news_id': memo['news_id'],
            'memo': memo['memo']
        }
        memo_list.append(memo_data)

    return jsonify(memo_list), 200

@app.route('/remove_scrap_news', methods=['POST'])
def remove_scrap_news():
    data = request.json
    key_number = data.get('title')

    cursor = mydb.cursor(dictionary=True)
    cursor.execute("SELECT * FROM scrap_news WHERE title = %s", (key_number,))
    result = cursor.fetchone()

    if result:
        cursor.execute("DELETE FROM scrap_news WHERE title = %s", (key_number,))
        mydb.commit()
        cursor.execute("DELETE FROM memo WHERE news_id = %s", (key_number,))
        mydb.commit()
        cursor.close()

        return jsonify({'message': 'Scrap news removed successfully.'}), 200
    else:
        cursor.close()
        return jsonify({'message': 'No news found for the provided key number.'}), 404

@app.route('/remove_memo', methods=['POST'])
def remove_memo():
    data = request.json
    memo_id = data.get('memo')

    cursor = mydb.cursor()

    try:
        sql = "SELECT * FROM memo WHERE memo = %s"
        val = (memo_id,)
        cursor.execute(sql, val)
        memo_record = cursor.fetchone()

        if memo_record:
            sql = "DELETE FROM memo WHERE memo = %s"
            cursor.execute(sql, val)
            mydb.commit()
            return "Memo removed successfully", 200
        else:
            cursor.close()
            return "Memo with specified ID not found", 404
    except Exception as e:
        error_message = f"An error occurred: {str(e)}"
        return error_message, 500

@app.route('/scrap_news', methods=['POST'])
def scrap_news():
    data = request.json
    keyword = data.get('keyword')
    key_number = data.get('key_number')

    cursor = mydb.cursor(dictionary=True)
    cursor.execute("SELECT * FROM news WHERE keyword = %s", (keyword,))
    news_data = cursor.fetchall()

    if news_data:
        if int(key_number) >= len(news_data):
            cursor.close()
            return jsonify({'message': 'Failed to scrap news. News not found for keyword: {} and key number: {}'.format(keyword, key_number)}), 404
        
        title = news_data[int(key_number)]['title']
        link = news_data[int(key_number)]['link']
        cursor.execute("INSERT INTO scrap_news (title, link) VALUES (%s, %s)", (title, link))
        mydb.commit()
        cursor.close()

        return jsonify({'message': 'News scrapped successfully for keyword: {} with key number: {}'.format(keyword, key_number)}), 200

    else:
        cursor.close()
        return jsonify({'message': 'Failed to scrap news. No news found for keyword: {}'.format(keyword)}), 404

@app.route('/get_news', methods=['GET'])
def get_news():
    keyword = request.args.get('keyword')

    if not keyword:
        return jsonify({'message': 'Please provide a keyword parameter.'}), 400
    news_data = get_news_from_database(keyword)

    if news_data:
        titles = [news['title'] for news in news_data]
        links = [news['link'] for news in news_data]
        return jsonify({'titles': titles, 'links': links}), 200
    else:
        return jsonify({'message': 'No news found for the provided keyword.'}), 404

@app.route('/get_keywords', methods=['GET'])
def get_keywords():
    cursor = mydb.cursor()
    cursor.execute("SELECT keyword FROM keywords")
    keywords_data = cursor.fetchall()
    cursor.close()

    keywords = [str(keyword[0]) for keyword in keywords_data]
    
    return jsonify({'keywords': keywords}), 200

@app.route('/get_subscribes', methods=['GET'])
def get_subscribes():
    cursor = mydb.cursor()
    cursor.execute("SELECT subscribe FROM subscribes")
    subscribes = cursor.fetchall()
    cursor.close()

    subscribe_list = [subscribe[0] for subscribe in subscribes]
    return jsonify({'keywords': subscribe_list}), 200

@app.route('/get_subscribe_news', methods=['GET'])
def get_subscribe_news():
    subscribe = request.args.get('subscribe')

    if subscribe:
        cursor = mydb.cursor()
        cursor.execute("SELECT * FROM subscribe_articles WHERE subscribe = %s", (subscribe,))
        subscribe_news = cursor.fetchall()
        cursor.close()

        if subscribe_news:
            news_list = []
            for news in subscribe_news:
                news_data = {
                    'ranking': str(news[1]) + '위',
                    'title': str(news[2]),
                    'link': str(news[3]),
                    'view': news[4]
                }
                news_list.append(news_data)

            return jsonify(news_list), 200
        else:
            return jsonify({'message': 'No news found for the provided subscribe.'}), 404
    else:
        return jsonify({'message': 'Please provide a subscribe parameter.'}), 400

@app.route('/crawl_news', methods=['POST'])
def crawl_news():
    crawl_news_for_all_keywords()
    current_time = time.strftime("%Y-%m-%d %H:%M:%S", time.localtime())
    return jsonify({'message': 'Crawling completed at ' + current_time})

@app.route('/crawl_subcribe_news', methods=['POST'])
def crawl_subscribe_news():
    crawl_news_for_all_subscribe()
    current_time = time.strftime("%Y-%m-%d %H:%M:%S", time.localtime())
    return jsonify({'message': 'Crawling completed at ' + current_time})

if __name__ == '__main__':
    id = {}    
    url_company = "https://news.naver.com/main/officeList.naver"
    html_company = urllib.request.urlopen(url_company).read()
    soup_company = BeautifulSoup(html_company, 'html.parser')
    title_company = soup_company.find_all(class_='list_press nclicks(\'rig.renws2pname\')')
    for i in title_company:
        parts = urlparse(i.attrs['href'])
        id[i.get_text().strip()] = parse_qs(parts.query)['officeId'][0]

    
    crawl_news_for_all_keywords()
    crawl_news_for_all_subscribe()
    
    current_time = time.strftime("%Y-%m-%d %H:%M:%S", time.localtime())
    print("Crawling completed at:", current_time)
    schedule.every(1).hour.do(crawl_news_job)
    schedule.every(1).hour.do(crawl_subscribe_job)
    threading.Thread(target=run_schedule, daemon=True).start()
    app.run(debug=True)