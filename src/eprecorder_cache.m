classdef eprecorder_cache < handle
    properties
        maxSize              % Maximum size of the cache
        currentSize          % Current size of the cache
        cacheMap             % Map to store key-value pairs
        accessOrder          % Order in which keys were accessed (for LRU policy)
        autoInvalidate       % Flag to enable or disable auto-invalidation
        invalidateInterval   % Interval for cache auto-invalidation in seconds
    end
    
    methods
        % Constructor
        function obj = eprecorder_cache(maxSize, autoInvalidate, invalidateInterval)
            obj.maxSize = maxSize;
            obj.currentSize = 0;
            obj.cacheMap = containers.Map;
            obj.accessOrder = [];
            obj.autoInvalidate = autoInvalidate;
            obj.invalidateInterval = invalidateInterval;
        end
        
        % Get Method
        function value = get(obj, key)
            keyStr = string(key);

            % Remove expired entries before checking for the key
            obj.removeExpiredEntries();

            if isKey(obj.cacheMap, keyStr)
                % Move the accessed key to the end of the access order
                obj.accessOrder(obj.accessOrder == keyStr) = [];
                obj.accessOrder = [obj.accessOrder; keyStr];

                % Return the unwrapped value associated with the key
                entry = obj.cacheMap(keyStr);
                value = entry.Value;
            else
                value = [];
                %disp(['Key "', num2str(key), '" not found in the cache.']);
            end
        end
        
        % Check if a key exists in the cache
        function exists = has(obj, key)
            keyStr = string(key);

            % Remove expired entries before checking for the key
            obj.removeExpiredEntries();

            exists = isKey(obj.cacheMap, keyStr);
            
            % If the key exists, move it to the end of the access order
            if exists
                obj.accessOrder(obj.accessOrder == keyStr) = [];
                obj.accessOrder = [obj.accessOrder; keyStr];
            end
        end
        
        % Put Method
        function put(obj, key, value)
            % If the cache is full, remove the least recently used item
            if obj.currentSize == obj.maxSize
                lruKey = obj.accessOrder(1);
                obj.cacheMap.remove(lruKey);
                obj.accessOrder = obj.accessOrder(2:end);
                obj.currentSize = obj.currentSize - 1;
            end
            
            % Add the new key-value pair to the cache
            keyStr = string(key);
            entry = struct('Value', value, 'Time', now);
            obj.cacheMap(keyStr) = entry;
            obj.accessOrder = [obj.accessOrder; keyStr];
            obj.currentSize = obj.currentSize + 1;
        end
        
        % Display Cache Method
        function displayCache(obj)
            disp('Current Cache:');
            keys = keys(obj.cacheMap);
            for i = 1:length(keys)
                key = keys{i};
                entry = obj.cacheMap(key);
                disp(['Key: "', key, '", Value: ', num2str(entry.Value)]);
            end
            disp(['Current Size: ', num2str(obj.currentSize), ', Max Size: ', num2str(obj.maxSize)]);
        end
        
        % Remove expired entries from the cache
        function removeExpiredEntries(obj)
            invalidateIntervalDays=obj.invalidateInterval/(24*60*60);
            
            keysToRemove = {};
            for i = 1:length(obj.accessOrder)
                key = obj.accessOrder(i);
                entry = obj.cacheMap(key);
                if now - entry.Time > invalidateIntervalDays
                    keysToRemove = [keysToRemove, key];
                end
            end

            % Remove expired entries
            for i = 1:length(keysToRemove)
                key = keysToRemove{i};
                obj.accessOrder(obj.accessOrder == key) = [];
                obj.cacheMap.remove(key);
                obj.currentSize = obj.currentSize - 1;
                disp(['Key "', key, '" removed due to expiration.']);
            end
        end

         % Clear the entire cache
        function clearCache(obj)
            obj.cacheMap = containers.Map;
            obj.accessOrder = [];
            obj.currentSize = 0;
            disp('Cache cleared.');
        end
    end
end
