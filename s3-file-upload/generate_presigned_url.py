#substitute for placehosders access_key_id and secret_access_key before running the script.


import boto3
s3 = boto3.client('s3')

s3 = boto3.client(
   's3',
   aws_access_key_id='<access_key_id>',
   aws_secret_access_key='<secret_access_key>'
) 

bucket = input("Bucket Name: ")
key= input("file name: ")

#print presigned URL
print(s3.generate_presigned_url('put_object', Params={'Bucket':bucket,'Key':key, 'ContentType':"text/plain"}, ExpiresIn=3600, HttpMethod='PUT'))
