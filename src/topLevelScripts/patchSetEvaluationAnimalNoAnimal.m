home = '/home/josh/data/ruleRiesenhuber2013/';
addpath(genpath([home 'src/']));

imgDir = [home 'imageSets/animalNoAnimal/'];
outDir = ensureDir([home 'evaluation/animalNoAnimal/']);

method = 'svm';
options = '-s 0 -t 0 -b 1 -q -c 0.1';
labels = [ones(1,600) zeros(1,600)];

if ~exist([outDir 'splits.mat'],'file')
    nTrainingExamples = [16 32 64 128 256 512 600 1024];
    nRuns = 40;
    cvsplit = cv(labels,nTrainingExamples,nRuns);
    save([outDir 'splits.mat'],'nTrainingExamples','nRuns','cvsplit');
    fprintf('splits generated\n');
else
    load([outDir 'splits.mat'])
    fprintf('splits loaded\n');
end

type0 = {'kmeans','random','random23'};
% k-means 400
for i = 1:length(type0)
    outFile = [outDir type0{i} '-evaluation.mat'];
    if ~exist(outFile,'file')
        animals = load([imgDir 'c2Cache/animals.' type0{i} '.c2.mat'], 'c2');
        noAnimals = load([imgDir 'c2Cache/noAnimals.' type0{i} '.c2.mat'], 'c2');
        c2 = [animals.c2 noAnimals.c2];
        [aucs,dprimes,models] = evaluatePerformance(c2,labels,cvsplit,method, ...
          options,size(c2,1),[]);
        save(outFile,'labels','c2','aucs','dprimes', 'models','-v7.3');
        clear animals noAnimals c2 aucs dprimes models outFile;
    end
    fprintf('%s evaluated\n',type0{i});
end

type1 = {'organic','inorganic'};
type2 = {'isolated','shared'};
for j = 1:length(type2)
    for i = 1:length(type1)
        % single patch type
        outFile = [outDir type1{i} '-' type2{j} '-evaluation.mat'];
        if ~exist(outFile,'file')
            animals = load([imgDir 'c2Cache/animals.' type1{i} '.' type2{j} '.c3.mat'], 'c3');
            noAnimals = load([imgDir 'c2Cache/noAnimals.' type1{i} '.' type2{j} '.c3.mat'], 'c3');
            c3 = [animals.c3 noAnimals.c3];
            [aucs,dprimes,models] = evaluatePerformance(c3,labels,cvsplit,method, ...
              options,size(c3,1),[]);
            save(outFile,'labels','c3','aucs','dprimes', 'models','-v7.3');
            clear animals noAnimals c3 aucs dprimes models outFile;
        end
        fprintf('%s - %s evaluated\n',type1{i},type2{j});
	% combined patch types
        outFile = [outDir type1{i} '-' type2{j} '-plus-kmeans-evaluation.mat'];
        if ~exist(outFile,'file')
            c2Animals = load([imgDir 'c2Cache/animals.kmeans.c2.mat'], 'c2');
            c2NoAnimals = load([imgDir 'c2Cache/noAnimals.kmeans.c2.mat'], 'c2');
            c3Animals = load([imgDir 'c2Cache/animals.' type1{i} '.' type2{j} '.c3.mat'], 'c3');
            c3NoAnimals = load([imgDir 'c2Cache/noAnimals.' type1{i} '.' type2{j} '.c3.mat'], 'c3');
            c2c3 = [c2Animals.c2 c2NoAnimals.c2; c3Animals.c3 c3NoAnimals.c3];
            [aucs,dprimes,models] = evaluatePerformance(c2c3,labels,cvsplit,method, ...
              options,size(c2c3,1),[]);
            save(outFile,'labels','c2c3','aucs','dprimes', 'models','-v7.3');
            clear animals noAnimals c2c3 aucs dprimes models outFile;
        end
        fprintf('%s - %s + k-means evaluated\n',type1{i},type2{j});
    end
    % Organic + Inorganic C3
    outFile = [outDir type2{j} '-all-C3-evaluation.mat'];
    if ~exist(outFile,'file')
        animalsOrganic = load([imgDir 'c2Cache/animals.organic.' type2{j} '.c3.mat'], 'c3');
        animalsInorganic = load([imgDir 'c2Cache/animals.inorganic.' type2{j} '.c3.mat'], 'c3');
        noAnimalsOrganic = load([imgDir 'c2Cache/noAnimals.organic.' type2{j} '.c3.mat'], 'c3');
        noAnimalsInorganic = load([imgDir 'c2Cache/noAnimals.inorganic.' type2{j} '.c3.mat'], 'c3');
        c3 = [animalsOrganic.c3   noAnimalsOrganic.c3; ...
              animalsInorganic.c3 noAnimalsInorganic.c3];
        [aucs,dprimes,models] = evaluatePerformance(c3,labels,cvsplit,method, ...
          options,size(c3,1),[]);
        save(outFile,'labels','c3','aucs','dprimes', 'models','-v7.3');
        clear animals noAnimals c3 aucs dprimes models outFile;
    end
    fprintf('%s all C3 evaluated\n',type2{j});
    
    % organic C3, inorganic C3, + k-means C2
    outFile = [outDir type2{j} '-all-C3-plus-kmeans-evaluation.mat'];
    if ~exist(outFile,'file')
        c2Animals = load([imgDir 'c2Cache/animals.kmeans.c2.mat'], 'c2');
        c2NoAnimals = load([imgDir 'c2Cache/noAnimals.kmeans.c2.mat'], 'c2');
        c3AnimalsOrganic = load([imgDir 'c2Cache/animals.organic.' type2{j} '.c3.mat'], 'c3');
        c3AnimalsInorganic = load([imgDir 'c2Cache/animals.inorganic.' type2{j} '.c3.mat'], 'c3');
        c3NoAnimalsOrganic = load([imgDir 'c2Cache/noAnimals.organic.' type2{j} '.c3.mat'], 'c3');
        c3NoAnimalsInorganic = load([imgDir 'c2Cache/noAnimals.inorganic.' type2{j} '.c3.mat'], 'c3');
        c2c3 = [c2Animals.c2          c2NoAnimals.c2 ; ... 
                c3AnimalsOrganic.c3   c3NoAnimalsOrganic.c3; ...
                c3AnimalsInorganic.c3 c3NoAnimalsInorganic.c3];
        [aucs,dprimes,models] = evaluatePerformance(c2c3,labels,cvsplit,method, ...
          options,size(c2c3,1),[]);
        save(outFile,'labels','c2c3','aucs','dprimes', 'models','-v7.3');
        clear animals noAnimals c2c3 aucs dprimes models outFile;
    end
    fprintf('%s all C3 + kmeans evaluated\n',type2{j});
end
