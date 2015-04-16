function p = linearAnAParams()
    home = '/home/josh/data/ruleRiesenhuber2013/';
    imgDir = [home 'imageSets/animalNoAnimal/'];
    patchDir = [home 'patchSets/'];
    patchSets = {'kmeans','random','randomTwoThirds'};

    p = struct( ...
        'home', home, ...
        'srcPath', [home 'src/'], ...
        'imgHome', '/home/josh/maxlab/image-sets/image-net/images/', ...
        'imgDir', imgDir, ...
        'outDir', ensureDir([home 'evaluation/AnA/']), ...
        'c2CacheDir', ensureDir([imgDir 'c2Cache/']), ...
        'patchDir', ensureDir(patchDir), ...
        'organicC3Dir', ensureDir([patchDir 'organicC3vLinear/']), ...
        'inorganicC3Dir', ensureDir([patchDir 'inorganicC3vLinear/']), ...
        'seed', 0, ...
        'nTrainingExamples', [16 32 64 128 256 512 600 1024], ...
        'nRuns', 40, ...
        'method', 'svm', ...
        'options', '-s 0 -t 0 -b 1 -q -c 0.1', ...
        'patchSets', {patchSets}, ...
        'caching', struct( ...
            'maxSize', 256, ...
            'patchFiles', {strcat(home,'patchSets/',patchSets,'.xml')}, ...
            'hmaxHome', [home 'src/hmax-ocv/'], ...
            'nImgs', 600));
end

function success = ensureDir(dirName)
% Author: Santosh Divvala
% Revised: saurabh.me@gmail.com (Saurabh Singh).
% Revised: rsj28@georgetown.edu (Josh Rule).
%
% Conditionally create a directory and return its path
%
% dirName: string, the absolute path of the directory
%
% success: string, the absolute path of the directory, empty on failure
    if exist(dirName, 'dir') || mkdir(dirName)
        success = dirName;
    else
        success = '';
    end
end
