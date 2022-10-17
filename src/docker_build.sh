#!/usr/bin/env bash
if [ -z "$1" ] 
   then
      echo "getting base image from base_image_uri.txt file"
      base_image=`cat base_image_uri.txt`
      echo $base_image
   else 
      base_image=$1
fi
namespace='custom_images'
region=$(aws configure get region)
account=$(aws sts get-caller-identity --query Account --output text)
base_account=${base_image:0:12}   # the first 12 characters of base image are for the aws account number hosting the public image
base_region=`expr  "${base_image:21}" : '\(.*\)\.amazon'`
regex='.*/(.*):(.*)'
[[ $base_image =~ $regex ]]
algorithm=${BASH_REMATCH[1]}
version=${BASH_REMATCH[2]}
echo $algorithm
echo $version
# the images are public, but still need an authentication token to access
token=$(base64 -d <<< $(aws ecr get-authorization-token --region $base_account  --registry-ids $base_account --output text --query 'authorizationData[].authorizationToken'))
echo ${token:4} | docker login --username AWS --password-stdin "${base_account}".dkr.ecr."${base_region}".amazonaws.com

docker pull "${base_image}" 

# tagging so dockerfile can resolve the base image easily
docker tag "${base_image}" base_image

# obtaining the path to xgboost modules inside the container
xgboost_path=`docker run -t base_image find / -name "sagemaker_xgboost_container" | tr -d '\r'`
echo $xgboost_path
docker build --build-arg  xgboost_path="${xgboost_path}/algorithm_mode" . -t custom_image


# now push to private registry
# first we need to logout from public ecr and login to our private one
docker logout
aws ecr get-login-password --region "${region}" | docker login --username AWS --password-stdin "${account}".dkr.ecr."${region}".amazonaws.com

# check if repo does not exist to create it
aws ecr describe-repositories --repository-names "${namespace}/${algorithm}-${version}" > /dev/null 2>&1

if [ $? -ne 0 ]
then
    aws ecr create-repository --repository-name "${namespace}/${algorithm}-${version}" > /dev/null
fi
# including the base algorithm and version to keep track of the origins of our custom container
fullname="${account}.dkr.ecr.${region}.amazonaws.com/${namespace}/${algorithm}-${version}"
echo $fullname
docker tag custom_image $fullname
docker push $fullname

