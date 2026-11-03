#!/usr/bin/python3

import os
import time
import sys
import argparse
from concurrent.futures import ThreadPoolExecutor
import requests
from threading import Lock
import hashlib

stdout_lock = Lock()

def safe_print(*args, **kwargs):
        with stdout_lock:
                print(*args, **kwargs)

parser = argparse.ArgumentParser(description='Process some integers.')
parser.add_argument('--subreddit', help='name of the subreddit')
parser.add_argument('--user', help='user name')
parser.add_argument('--sort', default='top', help='top or hot')

args = parser.parse_args()
safe_print(args)

if args.subreddit:
    sub_reddit = args.subreddit
    if args.sort == 'top':
        url = 'https://www.reddit.com/r/{0}/top.json?sort=top&t=all'.format(sub_reddit)
    else:
        url = 'https://www.reddit.com/r/{0}/.json?'.format(sub_reddit)
elif args.user:
    sub_reddit = args.user
    url = 'https://www.reddit.com/user/{0}.json'.format(sub_reddit)
else:
    raise parser.error('No user or subreddit name')

gfycat = 'https://gfycat.com/cajax/get/{0}'
redgifs = 'https://api.redgifs.com/v1/gfycats/{}'

headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 6.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/41.0.2228.0 Safari/537.36',
}

session = requests.Session()
session.headers.update(headers)

exceptions = {}
filenames = set()
downloaded_urls = set()
filenames_lock = Lock()
url_lock = Lock()
file_hashes = {}
hash_lock = Lock()

DOWNLOAD_ROOT = os.environ.get('REDDIT_DOWNLOAD_DIR', os.path.expanduser('~/gallery/reddit'))

def format_bytes(num):
        """Return a human-friendly file size."""
        step_unit = 1024.0
        for unit in ('B', 'KB', 'MB', 'GB', 'TB'):
                if num < step_unit or unit == 'TB':
                        return '{0:.1f} {1}'.format(num, unit)
                num /= step_unit

def register_file_by_hash(filepath):
        try:
                hasher = hashlib.sha256()
                with open(filepath, 'rb') as handle:
                        for chunk in iter(lambda: handle.read(8192), b''):
                                hasher.update(chunk)
        except OSError as exc:
                safe_print('Failed to hash file {0}: {1}'.format(filepath, exc))
                return None, None

        file_hash = hasher.hexdigest()
        with hash_lock:
                existing_path = file_hashes.get(file_hash)
                if existing_path:
                        return file_hash, existing_path
                file_hashes[file_hash] = filepath
        return file_hash, None

def handle_duplicate_file(filename):
        _, existing_path = register_file_by_hash(filename)
        if existing_path:
                safe_print('Duplicate content detected for {0}; matches {1}'.format(filename, existing_path))
                try:
                        os.remove(filename)
                except OSError as exc:
                        safe_print('Failed to remove duplicate {0}: {1}'.format(filename, exc))
                with filenames_lock:
                        filenames.discard(filename)
                return True
        return False

def get_gfycat_url(gfycat_name):
        response = session.get(gfycat.format(gfycat_name), headers=headers)

        if response.status_code == 200:
                response_json = response.json()
                mp4url = response_json['gfyItem']['mp4Url']
                return mp4url
        else:
                return False

def get_redgifs_url(redgifs_name):
        response = session.get(redgifs.format(redgifs_name), headers=headers)

        if response.status_code == 200:
                response_json = response.json()
                mp4url = response_json['gfyItem']['mp4Url']
                return mp4url
        else:
                return False

def report_progress(start_time, downloaded_bytes, total_size, label):
        duration = max(time.time() - start_time, 1e-6)
        speed_per_second = downloaded_bytes / duration if duration else 0
        speed_str = format_bytes(speed_per_second) + '/s'
        label = label or ''
        if len(label) > 32:
                label = label[:29] + '...'

        if total_size:
                percent = int(downloaded_bytes * 100 / total_size)
                bar_length = 28
                filled_length = int(bar_length * downloaded_bytes / total_size)
                filled_length = min(filled_length, bar_length)
                bar = '=' * filled_length + '.' * (bar_length - filled_length)
                total_str = format_bytes(total_size)
                downloaded_str = format_bytes(downloaded_bytes)
                message = '\r{0:<32} [{1}] {2:3d}% {3}/{4} {5}'.format(
                        label,
                        bar,
                        percent,
                        downloaded_str,
                        total_str,
                        speed_str,
                )
        else:
                downloaded_str = format_bytes(downloaded_bytes)
                message = '\r{0:<32} {1} downloaded {2}'.format(
                        label,
                        downloaded_str,
                        speed_str,
                )

        with stdout_lock:
                sys.stdout.write(message)
                sys.stdout.flush()

def download_with_session(url, filename, chunk_size=8192, progress_label=None):
    with session.get(url, stream=True) as response:
        response.raise_for_status()
        total_size = int(response.headers.get('content-length', 0) or 0)
        start_time = time.time()
        downloaded = 0
        progress_label = progress_label or os.path.basename(filename)
        with open(filename, 'wb') as handle:
            for chunk in response.iter_content(chunk_size=chunk_size):
                if not chunk:
                    continue
                handle.write(chunk)
                downloaded += len(chunk)
                report_progress(start_time, downloaded, total_size, progress_label)
        with stdout_lock:
                sys.stdout.write('\n')
                sys.stdout.flush()

def download_media(img_url, file_name, source, folder_name):
    try:
        file_path = folder_name
        if not os.path.exists(file_path):
            safe_print('???', file_path, '????????')
        os.makedirs(file_path, exist_ok=True)

        if source == 'gfycat.com':
                gfycat_name = img_url.split('/')[-1]
                img_url = get_gfycat_url(gfycat_name)
                if img_url:
                        file_suffix = os.path.splitext(img_url)[1]
                        filename = '{}{}{}{}'.format(file_path, os.sep, file_name, file_suffix)
                        with url_lock:
                                if img_url in downloaded_urls:
                                        safe_print("URL {0} already downloaded".format(img_url))
                                        return False
                                downloaded_urls.add(img_url)
                        with filenames_lock:
                                if os.path.exists(filename) or filename in filenames:
                                        safe_print("File {0} already exists".format(filename))
                                        downloaded_urls.discard(img_url)
                                        return False
                                filenames.add(filename)
                        safe_print('\nDownloading gfycat', img_url)
                        try:
                                download_with_session(
                                        img_url,
                                        filename,
                                        progress_label=os.path.basename(filename),
                                )
                                if handle_duplicate_file(filename):
                                        return False
                        except Exception:
                                with filenames_lock:
                                        filenames.discard(filename)
                                with url_lock:
                                        downloaded_urls.discard(img_url)
                                raise
        elif source == 'i.imgur.com':
                img_url = img_url.replace('.gifv', '.mp4')
                file_suffix = os.path.splitext(img_url)[1]
                filename = '{}{}{}{}'.format(file_path, os.sep, file_name, file_suffix)
                with url_lock:
                        if img_url in downloaded_urls:
                                safe_print("URL {0} already downloaded".format(img_url))
                                return False
                        downloaded_urls.add(img_url)
                with filenames_lock:
                        if os.path.exists(filename) or filename in filenames:
                                safe_print("File {0} already exists".format(filename))
                                downloaded_urls.discard(img_url)
                                return False
                        filenames.add(filename)
                safe_print('\nDownloading imgur', img_url)
                try:
                        download_with_session(
                                img_url,
                                filename,
                                progress_label=os.path.basename(filename),
                        )
                        if handle_duplicate_file(filename):
                                return False
                except Exception:
                        with filenames_lock:
                                filenames.discard(filename)
                        with url_lock:
                                downloaded_urls.discard(img_url)
                        raise
        elif source == 'i.redd.it':
                file_suffix = os.path.splitext(img_url)[1]
                filename = '{}{}{}{}'.format(file_path, os.sep, file_name, file_suffix)
                with url_lock:
                        if img_url in downloaded_urls:
                                safe_print("URL {0} already downloaded".format(img_url))
                                return False
                        downloaded_urls.add(img_url)
                with filenames_lock:
                        if os.path.exists(filename) or filename in filenames:
                                safe_print("File {0} already exists".format(filename))
                                downloaded_urls.discard(img_url)
                                return False
                        filenames.add(filename)
                safe_print('\nDownloading reddit', img_url)
                try:
                        download_with_session(
                                img_url,
                                filename,
                                progress_label=os.path.basename(filename),
                        )
                        if handle_duplicate_file(filename):
                                return False
                except Exception:
                        with filenames_lock:
                                filenames.discard(filename)
                        with url_lock:
                                downloaded_urls.discard(img_url)
                        raise
        elif source == 'redgifs.com':
                redgifs_name = img_url.split('/')[-1]
                img_url = get_redgifs_url(redgifs_name)
                if img_url:
                        file_suffix = os.path.splitext(img_url)[1]
                        filename = '{}{}{}{}'.format(file_path, os.sep, file_name, file_suffix)
                        with url_lock:
                                if img_url in downloaded_urls:
                                        safe_print("URL {0} already downloaded".format(img_url))
                                        return False
                                downloaded_urls.add(img_url)
                        with filenames_lock:
                                if os.path.exists(filename) or filename in filenames:
                                        safe_print("File {0} already exists".format(filename))
                                        downloaded_urls.discard(img_url)
                                        return False
                                filenames.add(filename)
                        safe_print('\nDownloading redgifs', img_url)
                        try:
                                download_with_session(
                                        img_url,
                                        filename,
                                        progress_label=os.path.basename(filename),
                                )
                                if handle_duplicate_file(filename):
                                        return False
                        except Exception:
                                with filenames_lock:
                                        filenames.discard(filename)
                                with url_lock:
                                        downloaded_urls.discard(img_url)
                                raise

        else:
                exceptions[source] = img_url

    except IOError as e:
        safe_print('??????', e)
    except Exception as e:
        safe_print('?? ?', e)

def process_post(post):
    try:
            source = post['data']['domain']
    except KeyError:
            safe_print('No domain in data object')
            return
    media_url = post['data']['url']
    filename = post['data']['title']
    download_media(
            media_url,
            filename.replace('/', '_'),
            source,
            os.path.join(DOWNLOAD_ROOT, sub_reddit),
    )

def request_reddit(initial_url):
        base_url, _, existing_query = initial_url.partition('?')
        current_url = initial_url

        while current_url:
                response = session.get(current_url, headers=headers)
                if response.status_code != 200:
                        safe_print(response)
                        break

                response_json = response.json()
                next_page = response_json['data']['after']
                posts = response_json['data']['children']

                with ThreadPoolExecutor(max_workers=16) as runner:
                    for post in posts:
                        runner.submit(process_post, post)

                if next_page:
                        safe_print("\nHeading over to next page ... ")
                        if existing_query:
                                current_url = f"{base_url}?{existing_query}&after={next_page}"
                        else:
                                current_url = f"{base_url}?after={next_page}"
                else:
                        current_url = None

request_reddit(url)
safe_print(exceptions)
