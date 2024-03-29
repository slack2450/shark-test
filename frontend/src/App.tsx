import sharkLogo from "./assets/shark.png";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Card, CardContent } from "@/components/ui/card";
import { ModeToggle } from "@/components/mode-toggle";
import { useToast } from "@/components/ui/use-toast";
import { LoadingSpinner } from "./components/ui/loading-spinner";

import axios from "axios";
import { useState } from "react";
import { motion } from "framer-motion";

axios.defaults.baseURL = "https://api.shark.plasam.dev/v1";

function App() {
  // Keep track of the number of packs to fetch
  const [packsToFetch, setPacksToFetch] = useState<number>(0);
  const [packs, setPacks] = useState<Record<string, string>>({});
  const [isFetching, setIsFetching] = useState<boolean>(false);

  const { toast } = useToast();

  // Fetch the packs from the server and update the state
  // with the response. If an error occurs, display a toast
  function fetchPacks() {
    setIsFetching(true);
    setPacks({});
    axios
      .get(`/packs/${packsToFetch}`)
      .then((response) => {
        setPacks(response.data);
        console.log(response.data);
      })
      .catch((error) => {
        console.error(error);
        toast({
          variant: "destructive",
          title: "An error occurred while fetching packs",
        });
      })
      .finally(() => {
        setIsFetching(false);
      });
  }

  return (
    <>
      <img
        src={sharkLogo}
        className="mt-6 max-w-24 m-auto dark:invert"
        alt="GymShark Logo"
      />
      <div className="flex space-x-2 m-auto justify-center ">
        <h1 className="text-4xl font-bold mb-2">Package Shark</h1>
        <ModeToggle />
      </div>

      <div className="flex space-x-2 max-w-md m-auto mb-3 pl-2 pr-2">
        <Input
          className="text-1xl"
          onChange={(e) => setPacksToFetch(Math.max(parseInt(e.target.value) || 0, 0))}
          value={packsToFetch}
          type="text"
          placeholder="Number of items"
          pattern="[0-9]*"
          inputMode="numeric"
        />
        <Button className="text-1xl w-12" onClick={() => fetchPacks()}>
          {
            isFetching ? <LoadingSpinner size={16} /> : "Go"
          }
        </Button>
      </div>
      <div className="flex space-x-2 m-auto max-w-md justify-between mb-2 pl-2 pr-1.5">
        <Button onClick={() => setPacksToFetch(Math.max(packsToFetch-1000,0))}>-1000</Button>
        <Button onClick={() => setPacksToFetch(Math.max(packsToFetch-100,0))}>-100</Button>
        <Button onClick={() => setPacksToFetch(0)}>Reset</Button>
        <Button onClick={() => setPacksToFetch(Math.max(packsToFetch+100,0))}>+100</Button>
        <Button onClick={() => setPacksToFetch(Math.max(packsToFetch+1000,0))}>+1000</Button>
      </div>
      <p className="text-1xl text-slate-400 mb-4 text-center">
        Enter the number of items you want to order and click Go.
      </p>

      <div className="ml-2 mr-2">
        {
          // Render the packs as cards, sorted by pack size descending
          Object.entries(packs)
            .sort((a, b) => parseInt(b[0]) - parseInt(a[0]))
            .map(([packSize, quantity], index) => (
              <Pack key={packSize} packSize={packSize} quantity={quantity} index={index} />
            ))
        }
      </div>
    </>
  );
}

function Pack({
  packSize,
  quantity,
  index,
}: {
  packSize: string;
  quantity: string;
  index: number;
}) {
  return (
    <motion.div
      initial={{ y: -25, opacity: 0 }}
      animate={{ y: 0, opacity: 1 }}
      transition={{ duration: 0.25, type: "spring", delay: index / 20 }}
    >
      <Card className="max-w-md m-auto mb-2">
        <CardContent className="p-4 flex justify-between items-end">
          <h2 className="text-2xl font-bold">Pack of {packSize}</h2>
          <p className="text-1xl text-right text-slate-400">x{quantity}</p>
        </CardContent>
      </Card>
    </motion.div>
  );
}

export default App;
